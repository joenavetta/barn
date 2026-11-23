terraform {
  backend "gcs" {
    prefix = "stacks/pve-02"
  }
}
