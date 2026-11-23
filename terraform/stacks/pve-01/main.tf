# Guests on pve-01 (MS-03): application VMs/LXCs such as NetBox, Mealie, Immich.
#
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
