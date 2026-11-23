# Shared, non-secret values every stack reads with:
#   module "globals" { source = "../../modules/globals" }
# Change a value here once instead of in each stack.

output "zone" {
  description = "Public apex domain in Cloudflare"
  value       = "cowshed.cc"
}

output "internal_domain" {
  value = "home.cowshed.cc"
}

output "onepassword" {
  description = "Vault and item titles Terraform reads secrets from (naming: docs/secrets.md)"
  value = {
    account = "PW5WK2EEO5HM5L4UG46ABS37TA" # desktop app integration (Touch ID)
    vault   = "Home Infrastructure"
    items = {
      proxmox_pve_01 = "terraform.proxmox.pve-01"
      proxmox_pve_02 = "terraform.proxmox.pve-02"
      cloudflare     = "terraform.cloudflare.default"
      unifi          = "terraform.unifi.default"
      opnsense       = "terraform.opnsense.default"
    }
  }
}

output "proxmox_nodes" {
  value = {
    pve-01 = { endpoint = "https://pve-01.home.cowshed.cc:8006/" }
    pve-02 = { endpoint = "https://pve-02.home.cowshed.cc:8006/" }
  }
}

output "networks" {
  description = "VLANs, filled in as the design in docs/network.md settles"
  value       = {}
}

output "ssh_public_keys" {
  value = []
}
