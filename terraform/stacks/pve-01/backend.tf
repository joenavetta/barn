terraform {
  backend "gcs" {
    prefix = "stacks/pve-01"
  }
}
