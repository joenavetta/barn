# Guests on pve-01 (MS-03): application VMs/LXCs such as NetBox, Mealie, Immich.

locals {
  node = "pve-01"

  # Management is the untagged native network (UniFi "Default"), so no VLAN tag.
  mgmt     = module.globals.networks.mgmt
  unifi_ip = module.globals.hosts.unifi
}

# --- UniFi OS Server --------------------------------------------------------
# Self-hosted UniFi console that runs UniFi Network (11+). It replaces the
# standalone UniFi Network Server, whose last release is 10.6. It runs its own
# Podman container, so it gets a VM (Ubiquiti's supported setup) instead of an
# LXC. It sits in Management next to the switch and APs it adopts.
#
# Cloud-init installs Podman and runs the installer on first boot. After that,
# UniFi OS updates itself from its own UI, so changing unifi_os_server_url later
# does not upgrade a running VM.

resource "proxmox_virtual_environment_file" "unifi_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.node

  source_raw {
    file_name = "unifi-user-data.yaml"
    data = templatefile("${path.module}/templates/unifi-user-data.yaml.tftpl", {
      hostname        = "unifi"
      fqdn            = "unifi.${module.globals.internal_domain}"
      ssh_public_keys = module.globals.ssh_public_keys
      installer_url   = var.unifi_os_server_url
      installer_sha   = var.unifi_os_server_sha256
    })
  }
}

module "unifi" {
  source      = "../../modules/proxmox-vm"
  name        = "unifi"
  description = "UniFi OS Server (UniFi Network controller). Web UI https://unifi.${module.globals.internal_domain}:11443"
  node        = local.node

  template_vm_id = var.debian_template_vm_id

  # Ubiquiti's tier for up to 25 devices / 250 clients: 2 cores, 2 GB RAM
  # (+2 GB swap), 50 GB. RAM doubled for headroom.
  cores     = 2
  memory_mb = 4096
  disk_gb   = 50

  ipv4_cidr    = "${local.unifi_ip}/${split("/", local.mgmt.cidr)[1]}"
  ipv4_gateway = local.mgmt.gateway
  dns_servers  = [local.mgmt.gateway]
  dns_domain   = module.globals.internal_domain

  user_data_file_id = proxmox_virtual_environment_file.unifi_user_data.id
  tags              = ["network", "unifi"]
}

output "unifi" {
  value = {
    vm_id  = module.unifi.vm_id
    web_ui = "https://${local.unifi_ip}:11443/"
    inform = "http://${local.unifi_ip}:8080/inform"
  }
}

# module "netbox" {
#   source          = "../../modules/proxmox-vm"
#   name            = "netbox"
#   node            = "pve-01"
#   template_vm_id  = 9000
#   cores           = 2
#   memory_mb       = 4096
#   disk_gb         = 40
#   ssh_public_keys = module.globals.ssh_public_keys
#   tags            = ["app"]
# }
