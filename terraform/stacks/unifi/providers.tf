terraform {
  required_version = ">= 1.5"
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.65"
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

# Credentials come from the environment: OP_SERVICE_ACCOUNT_TOKEN (read-only
# service account) or OP_ACCOUNT (desktop app, Touch ID), never both. Source
# lib/shell/op-env.sh in your shell to set one (docs/1password-service-account.md).
provider "onepassword" {}

# API key for a Limited Admin, Local Access Only account on the controller
# (Settings > Control Plane > Integrations), stored in `credential`.
data "onepassword_item" "unifi" {
  vault = module.globals.onepassword.vault
  title = module.globals.onepassword.items.unifi
}

provider "unifi" {
  # UniFi OS Server serves the Network API on 11443, not 8443.
  api_url = "https://${module.globals.hosts.unifi}:11443"
  api_key = data.onepassword_item.unifi.credential
  # Self-signed controller cert until a home.cowshed.cc cert is installed.
  allow_insecure = true
}
