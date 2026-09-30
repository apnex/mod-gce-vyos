## image: GCE records the concrete image a family resolves to, so passing a family path
## straight through would diff on every plan; resolve it here instead
locals {
  image_family = try(regex("^(?:https://www.googleapis.com/compute/v1/)?projects/([^/]+)/global/images/family/([^/]+)$", var.image), null)
}

data "google_compute_image" "family" {
  count   = local.image_family == null ? 0 : 1
  project = local.image_family[0]
  family  = local.image_family[1]
}

locals {
  image = local.image_family == null ? var.image : data.google_compute_image.family[0].self_link
}

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

  # GCE nicN is VyOS ethN. cloud-init configures eth0 by DHCP; eth1 and later need explicit
  # config, and only nic0 may carry the default route (GCE hands it out on nic0 only)
  interface_commands = flatten([
    for i, ni in var.network_interfaces : concat(
      i > 0 && ni.dhcp ? [
        "set interfaces ethernet eth${i} address 'dhcp'",
        "set interfaces ethernet eth${i} dhcp-options no-default-route",
      ] : [],
      ni.description != null ? ["set interfaces ethernet eth${i} description '${ni.description}'"] : [],
    )
  ])

  # set-syntax config: one command per line, blank lines and # comments dropped.
  # cloud-init (cc_vyos_userdata) treats everything before the first single quote as the
  # config path, so leaf values must be single-quoted: address '10.0.0.1/32', not address 10.0.0.1/32
  vyos_config_lines = [
    for line in split("\n", coalesce(var.vyos_config, "")) : trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]

  vyos_config_commands = concat(
    [local.ssh_password_command],
    local.interface_commands,
    local.vyos_config_lines,
    var.vyos_config_commands,
  )
  rendered_user_data = join("\n", [
    "#cloud-config",
    yamlencode({ vyos_config_commands = local.vyos_config_commands }),
  ])
  user_data = var.user_data != null ? var.user_data : local.rendered_user_data
}

## cloud-init applies user data on first boot only; tracking its hash lets a change replace
## the instance instead of silently updating metadata the router never reads again
resource "terraform_data" "config" {
  input = var.replace_on_config_change ? sha256(local.user_data) : "replace_on_config_change disabled"
}

resource "google_compute_instance" "vyos" {
  project                   = var.project_id
  zone                      = var.zone
  name                      = var.name
  machine_type              = var.machine_type
  can_ip_forward            = var.can_ip_forward
  tags                      = var.tags
  labels                    = var.labels
  deletion_protection       = var.deletion_protection
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = local.image
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
      dynamic "alias_ip_range" {
        for_each = network_interface.value.alias_ip_ranges
        content {
          ip_cidr_range         = alias_ip_range.value.ip_cidr_range
          subnetwork_range_name = alias_ip_range.value.subnetwork_range_name
        }
      }
    }
  }

  shielded_instance_config {
    enable_secure_boot          = var.secure_boot
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

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

  lifecycle {
    replace_triggered_by = [terraform_data.config]
  }
}
