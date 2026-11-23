resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node
  vm_id     = var.vm_id
  tags      = var.tags

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
    datastore_id = var.datastore
    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_cidr == "dhcp" ? null : var.ipv4_gateway
      }
    }
    user_account {
      keys = var.ssh_public_keys
    }
  }
}
