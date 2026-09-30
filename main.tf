## login key: generated unless the caller supplies one
resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "ED25519"
}

locals {
  ssh_user       = "vyos"
  ssh_public_key = var.ssh_public_key != null ? var.ssh_public_key : "${trimspace(tls_private_key.ssh[0].public_key_openssh)} ${var.name}"

  # user-data vyos_config_commands replace the image's list under cloud-init's merge,
  # so the SSH password setting always leads the rendered list
  ssh_password_command = var.ssh_password_authentication ? "delete service ssh disable-password-authentication" : "set service ssh disable-password-authentication"
  rendered_user_data = join("\n", [
    "#cloud-config",
    yamlencode({ vyos_config_commands = concat([local.ssh_password_command], var.vyos_config_commands) }),
  ])
  user_data = var.user_data != null ? var.user_data : local.rendered_user_data
}

resource "google_compute_instance" "vyos" {
  project                   = var.project_id
  zone                      = var.zone
  name                      = var.name
  machine_type              = var.machine_type
  can_ip_forward            = var.can_ip_forward
  tags                      = var.tags
  labels                    = var.labels
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = var.disk_type
    }
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      subnetwork = network_interface.value.subnetwork
      nic_type   = network_interface.value.nic_type
      network_ip = network_interface.value.network_ip
      dynamic "access_config" {
        for_each = network_interface.value.external_ip ? [1] : []
        content {
          nat_ip = network_interface.value.nat_ip
        }
      }
    }
  }

  shielded_instance_config {
    enable_secure_boot          = var.secure_boot
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # cloud-init reads these on first boot only; later changes update metadata but not VyOS config
  metadata = merge(var.metadata, {
    ssh-keys           = "${local.ssh_user}:${local.ssh_public_key}"
    user-data          = local.user_data
    enable-oslogin     = "FALSE"
    serial-port-enable = var.serial_port_enable ? "TRUE" : "FALSE"
  })

  dynamic "service_account" {
    for_each = var.service_account_email == null ? [] : [1]
    content {
      email  = var.service_account_email
      scopes = var.service_account_scopes
    }
  }
}
