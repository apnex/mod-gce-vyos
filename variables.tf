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
  description = "VyOS image: a self link, projects/<p>/global/images/<name>, or projects/<p>/global/images/family/<family>. A family is resolved to its current image at plan time, so a newer image in the family replaces the instance on the next apply; pass a concrete image to pin it."
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
  description = <<-EOT
    Interfaces in order: the Nth entry is GCE nicN and VyOS ethN. Each needs its own subnet, normally in its own VPC network.
    - subnetwork: subnet self link or id
    - nic_type: GVNIC (default) or VIRTIO_NET
    - network_ip: fixed internal IP; null lets GCE assign one
    - external_ip / nat_ip: add an access config, optionally with a reserved address
    - alias_ip_ranges: extra ranges routed to this interface by the VPC
    - description: VyOS interface description
    - dhcp: configure VyOS ethN by DHCP (default true). eth0 always keeps the default route; eth1 and later use no-default-route.
    The maximum number of interfaces follows the vCPU count: 2 for 2 or fewer vCPUs (e2-small, e2-medium), 4 for e2-standard-4, 8 for e2-standard-8.
  EOT
  type = list(object({
    subnetwork  = string
    nic_type    = optional(string, "GVNIC")
    network_ip  = optional(string)
    external_ip = optional(bool, false)
    nat_ip      = optional(string)
    alias_ip_ranges = optional(list(object({
      ip_cidr_range         = string
      subnetwork_range_name = optional(string)
    })), [])
    description = optional(string)
    dhcp        = optional(bool, true)
  }))
  validation {
    condition     = length(var.network_interfaces) >= 1 && length(var.network_interfaces) <= 10
    error_message = "Between 1 and 10 network interfaces are required."
  }
  validation {
    condition     = alltrue([for ni in var.network_interfaces : contains(["GVNIC", "VIRTIO_NET"], ni.nic_type)])
    error_message = "nic_type must be GVNIC or VIRTIO_NET."
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

variable "vyos_config" {
  description = "VyOS configuration in set syntax, one command per line, applied by cloud-init on first boot; blank lines and lines starting with # are ignored. Leaf values must be single-quoted (address '10.0.0.1/32'), because cloud-init reads everything before the first quote as the config path. Suits templatefile() over a per-router config file."
  type        = string
  default     = null
}

variable "vyos_config_commands" {
  description = "VyOS configuration commands applied by cloud-init on first boot, after vyos_config. Leaf values must be single-quoted, for example \"set system time-zone 'UTC'\"."
  type        = list(string)
  default     = []
}

variable "replace_on_config_change" {
  description = "Replace the instance when its rendered first-boot configuration changes, so the running router always matches the code. False updates metadata only, which cloud-init does not re-apply."
  type        = bool
  default     = true
}

variable "user_data" {
  description = "Raw cloud-init user data. Replaces the rendered user data entirely, including interface setup and the SSH password setting; mutually exclusive with vyos_config and vyos_config_commands."
  type        = string
  default     = null
  validation {
    condition     = var.user_data == null || (length(var.vyos_config_commands) == 0 && var.vyos_config == null)
    error_message = "Set either user_data or vyos_config / vyos_config_commands, not both."
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

variable "deletion_protection" {
  description = "Protect the instance from deletion; Terraform cannot destroy it until this is set back to false."
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
