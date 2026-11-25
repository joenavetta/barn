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

# Credentials come from the environment: run Terraform as `barn-tf`, which sets
# OP_SERVICE_ACCOUNT_TOKEN (service account) or OP_ACCOUNT (desktop app, Touch ID).
provider "onepassword" {}

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
