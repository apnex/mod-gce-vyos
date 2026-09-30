## placement

variable "project_id" {
  description = "Project for the instance."
  type        = string
}

variable "zone" {
  description = "Zone for the instance."
  type        = string
}

variable "name" {
  description = "Instance name; VyOS cloud-init also uses it as the hostname."
  type        = string
}

variable "machine_type" {
  description = "Machine type."
  type        = string
  default     = "e2-small"
}

variable "image" {
  description = "VyOS image: a self link, projects/<p>/global/images/<name>, or projects/<p>/global/images/family/<family>."
  type        = string
}

variable "disk_size_gb" {
  description = "Boot disk size in GB. Null uses the image size."
  type        = number
  default     = null
}

variable "disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "pd-balanced"
}

## networking

variable "network_interfaces" {
  description = "Interfaces in order (eth0, eth1, ...). nic_type is GVNIC or VIRTIO_NET (null = platform default); external_ip adds an access config, optionally with a reserved nat_ip."
  type = list(object({
    subnetwork  = string
    nic_type    = optional(string)
    network_ip  = optional(string)
    external_ip = optional(bool, false)
    nat_ip      = optional(string)
  }))
  validation {
    condition     = length(var.network_interfaces) >= 1
    error_message = "At least one network interface is required."
  }
}

variable "can_ip_forward" {
  description = "Allow the instance to forward packets it did not originate; routers need this."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Network tags, for firewall targeting."
  type        = list(string)
  default     = []
}

## access and configuration

variable "ssh_public_key" {
  description = "OpenSSH public key for user vyos. Null generates an ed25519 key pair and exposes the private key as the sensitive ssh_private_key output."
  type        = string
  default     = null
}

variable "ssh_password_authentication" {
  description = "Allow SSH password login. Applied as the first vyos_config_command, so it holds regardless of what the image default is."
  type        = bool
  default     = false
}

variable "vyos_config_commands" {
  description = "VyOS configuration commands applied by cloud-init on first boot (for example \"set interfaces ethernet eth1 address dhcp\")."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Raw cloud-init user data. Replaces the rendered user data entirely, including the SSH password setting; mutually exclusive with vyos_config_commands."
  type        = string
  default     = null
  validation {
    condition     = var.user_data == null || length(var.vyos_config_commands) == 0
    error_message = "Set either user_data or vyos_config_commands, not both."
  }
}

variable "metadata" {
  description = "Additional instance metadata. ssh-keys, user-data, enable-oslogin and serial-port-enable are managed by the module."
  type        = map(string)
  default     = {}
}

## platform

variable "serial_port_enable" {
  description = "Enable the interactive serial console (password login stays available there for recovery). Some organisations forbid it via compute.disableSerialPortAccess; serial output is readable either way."
  type        = bool
  default     = false
}

variable "secure_boot" {
  description = "Enable Shielded VM secure boot."
  type        = bool
  default     = false
}

variable "service_account_email" {
  description = "Service account to attach. Null attaches none; VyOS does not need one."
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "Scopes for the attached service account."
  type        = list(string)
  default     = ["cloud-platform"]
}

variable "labels" {
  description = "Labels for the instance."
  type        = map(string)
  default     = {}
}
