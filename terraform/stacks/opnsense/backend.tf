terraform {
  backend "gcs" {
    prefix = "stacks/opnsense"
  }
}
