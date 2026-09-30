## SYN
Deploys a VyOS router on GCE from a VyOS image, with SSH key login and first-boot VyOS configuration.\
The example below builds the image with [`mod-vyos-image`](https://github.com/apnex/mod-vyos-image) and boots a router from it.

### main.tf
```
locals {
	project_id	= "my-project"
	region		= "us-central1"
	zone		= "us-central1-a"
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
machine_type			= "e2-small"	# 2 vCPUs = 2 NICs; e2-standard-4 = 4, e2-standard-8 = 8
image				= "projects/<project>/global/images/family/vyos-rolling"	# family resolves to its latest image
network_interfaces		= [ ... ]	# nicN = ethN; each needs its own subnet, normally its own VPC
can_ip_forward			= true
ssh_public_key			= null		# supply your own key; null generates one (ssh_private_key output)
vyos_config			= null		# set-syntax config, e.g. templatefile("router.cfg.tftpl", {...})
vyos_config_commands		= []		# extra commands, applied after vyos_config
replace_on_config_change	= true		# replace the router when its first-boot config changes
ssh_password_authentication	= false		# true allows SSH password login
serial_port_enable		= false		# true enables the interactive serial console
deletion_protection		= false
```

Per interface:
```
{
	subnetwork	= "<subnet self link>"
	nic_type	= "GVNIC"	# or "VIRTIO_NET"
	network_ip	= "10.0.0.2"	# fixed internal ip; null = assigned
	external_ip	= false
	nat_ip		= null		# reserved external ip
	alias_ip_ranges	= []		# [{ ip_cidr_range = "10.1.0.0/24" }]
	description	= "transit"
	dhcp		= true		# eth1+ get address dhcp + no-default-route
}
```

### notes
- Leaf values in `vyos_config` and `vyos_config_commands` must be single-quoted: `set interfaces dummy dum0 address '10.0.0.1/32'`. cloud-init reads everything before the first quote as the config path, and an unquoted value breaks the whole first-boot config
- GCE hands the default route to nic0 only, so eth1 and later are configured with `no-default-route`
- First-boot configuration is applied once; with `replace_on_config_change = true` a change replaces the router, otherwise it only updates metadata
- The generated private key is also held in Terraform state
- Raw `user_data` replaces the rendered configuration entirely, including interface setup and the SSH password setting
