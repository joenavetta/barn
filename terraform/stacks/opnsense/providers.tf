terraform {
  required_version = ">= 1.5"
  required_providers {
    opnsense = {
      source  = "browningluke/opnsense"
      version = "~> 0.26"
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

# API key for a dedicated OPNsense user (System > Access > Users), stored as an
# API Credential: username = key, credential = secret.
data "onepassword_item" "opnsense" {
  vault = module.globals.onepassword.vault
  title = module.globals.onepassword.items.opnsense
}

provider "opnsense" {
  uri        = "https://${module.globals.hosts.opnsense}"
  api_key    = data.onepassword_item.opnsense.username
  api_secret = data.onepassword_item.opnsense.credential
  # The GUI cert is self-signed until a home.cowshed.cc cert is installed.
  allow_insecure = true
}
