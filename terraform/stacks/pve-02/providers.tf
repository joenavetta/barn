terraform {
  required_version = ">= 1.5"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.1"
    }
  }
}

module "globals" {
  source = "../../modules/globals"
}

# Uses the 1Password desktop app; each run is approved with Touch ID.
provider "onepassword" {
  account = module.globals.onepassword.account
}

data "onepassword_item" "proxmox" {
  vault = module.globals.onepassword.vault
  title = module.globals.onepassword.items.proxmox_pve_02
}

provider "proxmox" {
  endpoint  = module.globals.proxmox_nodes["pve-02"].endpoint
  api_token = data.onepassword_item.proxmox.credential

  ssh {
    agent = true
  }
}
