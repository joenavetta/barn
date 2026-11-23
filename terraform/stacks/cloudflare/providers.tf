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

# Uses the 1Password desktop app; each run is approved with Touch ID.
provider "onepassword" {
  account = module.globals.onepassword.account
}

data "onepassword_item" "cloudflare" {
  vault = module.globals.onepassword.vault
  title = module.globals.onepassword.items.cloudflare
}

provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare.credential
}
