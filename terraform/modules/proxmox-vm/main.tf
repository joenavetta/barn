resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  node_name   = var.node
  vm_id       = var.vm_id
  tags        = var.tags
  on_boot     = var.on_boot

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  initialization {
    datastore_id      = var.datastore
    user_data_file_id = var.user_data_file_id

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        domain  = var.dns_domain
        servers = var.dns_servers
      }
    }

    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_cidr == "dhcp" ? null : var.ipv4_gateway
      }
    }
    # Custom user-data replaces the generated user account, so callers that
    # pass user_data_file_id put their SSH keys in the user-data instead.
    dynamic "user_account" {
      for_each = var.user_data_file_id == null ? [1] : []
      content {
        keys = var.ssh_public_keys
      }
    }
  }
}
