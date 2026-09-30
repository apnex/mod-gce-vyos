## SYN
Deploys a VyOS router on GCE from a VyOS image, with SSH key login and first-boot VyOS configuration.\
The example below builds the image with [`mod-vyos-image`](https://github.com/apnex/mod-vyos-image) and boots a router from it.

### main.tf
```
locals {
	project_id	= "my-project"
	region		= "australia-southeast1"
	zone		= "australia-southeast1-a"
	ssh_source	= "203.0.113.10/32" # your public ip
}

module "vyos_image" {
	source		= "github.com/apnex/mod-vyos-image"
	project_id	= local.project_id
	region		= local.region
}

resource "google_compute_network" "vyos" {
	project			= local.project_id
	name			= "vyos"
	auto_create_subnetworks	= false
}

resource "google_compute_subnetwork" "vyos" {
	project		= local.project_id
	name		= "vyos"
	network		= google_compute_network.vyos.id
	region		= local.region
	ip_cidr_range	= "10.0.0.0/24"
}

resource "google_compute_firewall" "ssh" {
	project		= local.project_id
	name		= "vyos-allow-ssh"
	network		= google_compute_network.vyos.id
	source_ranges	= [local.ssh_source]
	allow {
		protocol	= "tcp"
		ports		= ["22"]
	}
}

module "router" {
	source		= "github.com/apnex/mod-gce-vyos"
	project_id	= local.project_id
	zone		= local.zone
	name		= "router-a"
	image		= module.vyos_image.image_self_link
	network_interfaces = [
		{
			subnetwork	= google_compute_subnetwork.vyos.id
			external_ip	= true
		}
	]
	vyos_config_commands = [
		"set service ntp server metadata.google.internal"
	]
}

resource "local_sensitive_file" "ssh_key" {
	content		= module.router.ssh_private_key
	filename	= "${path.module}/router-a.key"
	file_permission	= "0600"
}

output "router_address" {
	value = module.router.address
}
```

### apply
```
terraform init
terraform plan
terraform apply -auto-approve
```

### login
```
ssh -i router-a.key vyos@$(terraform output -raw router_address)
```

### options
All inputs are described in `variables.tf`; the common ones:
```
machine_type			= "e2-small"
image				= "projects/<project>/global/images/family/vyos-rolling"	# any VyOS GCE image
network_interfaces		= [ ... ]	# eth0, eth1, ... each with subnetwork, nic_type, network_ip, external_ip
nic_type			= "GVNIC"	# per interface; "VIRTIO_NET" for the legacy virtio NIC
can_ip_forward			= true
ssh_public_key			= null		# supply your own key; null generates one (ssh_private_key output)
vyos_config_commands		= []		# applied by cloud-init on first boot
ssh_password_authentication	= false		# true allows SSH password login
serial_port_enable		= false		# true enables the interactive serial console
```

### notes
- The generated private key is also held in Terraform state
- `vyos_config_commands` run on first boot only; later changes update instance metadata but not the running configuration
- Raw `user_data` replaces the rendered configuration entirely, including the SSH password setting
