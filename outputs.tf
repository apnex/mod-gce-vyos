output "name" {
  description = "Instance name."
  value       = google_compute_instance.vyos.name
}

output "self_link" {
  description = "Instance self link."
  value       = google_compute_instance.vyos.self_link
}

output "zone" {
  description = "Instance zone."
  value       = google_compute_instance.vyos.zone
}

output "id" {
  description = "Instance id (projects/<project>/zones/<zone>/instances/<name>)."
  value       = google_compute_instance.vyos.id
}

output "instance_id" {
  description = "Server-assigned unique instance id; unlike name and self link, it changes whenever the instance is replaced."
  value       = google_compute_instance.vyos.instance_id
}

output "interfaces" {
  description = "Per-interface details in order: VyOS name, GCE name, network, subnetwork, internal IP and external IP (null where absent)."
  value = [
    for i, ni in google_compute_instance.vyos.network_interface : {
      vyos_name   = "eth${i}"
      gce_name    = ni.name
      network     = ni.network
      subnetwork  = ni.subnetwork
      internal_ip = ni.network_ip
      external_ip = try(ni.access_config[0].nat_ip, null)
    }
  ]
}

output "vyos_config_commands" {
  description = "The full first-boot command list rendered into user data (empty when raw user_data is used)."
  value       = var.user_data == null ? local.vyos_config_commands : []
}

output "internal_ips" {
  description = "Internal IP per interface, in interface order."
  value       = [for ni in google_compute_instance.vyos.network_interface : ni.network_ip]
}

output "external_ips" {
  description = "External IP per interface, in interface order; null where an interface has none."
  value       = [for ni in google_compute_instance.vyos.network_interface : try(ni.access_config[0].nat_ip, null)]
}

output "address" {
  description = "Address to log in to: the first external IP, else the first internal IP."
  value = coalesce(
    try([for ni in google_compute_instance.vyos.network_interface : ni.access_config[0].nat_ip if length(ni.access_config) > 0][0], null),
    google_compute_instance.vyos.network_interface[0].network_ip,
  )
}

output "ssh_user" {
  description = "Login user."
  value       = local.ssh_user
}

output "ssh_public_key" {
  description = "Public key installed for the login user."
  value       = local.ssh_public_key
}

output "ssh_private_key" {
  description = "Generated private key (OpenSSH format); null when ssh_public_key was supplied."
  value       = var.ssh_public_key == null ? tls_private_key.ssh[0].private_key_openssh : null
  sensitive   = true
}

output "serial_console_command" {
  description = "Command that prints the instance serial console."
  value       = "gcloud compute instances get-serial-port-output ${google_compute_instance.vyos.name} --zone ${google_compute_instance.vyos.zone} --project ${var.project_id}"
}
