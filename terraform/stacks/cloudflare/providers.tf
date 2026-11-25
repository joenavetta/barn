terraform {
  required_version = ">= 1.5"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
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

data "onepassword_item" "cloudflare" {
  vault = module.globals.onepassword.vault
  title = module.globals.onepassword.items.cloudflare
}

provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare.credential
}
