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
