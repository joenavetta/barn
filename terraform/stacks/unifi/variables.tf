variable "networks_enabled" {
  description = "Tagged networks (module.globals.networks keys) to create. Keep in step with stacks/opnsense networks_enabled"
  type        = list(string)
  default     = ["iot"]
}

variable "wlans_enabled" {
  description = "Create the SSIDs. Needs the unifi.wifi.* items and real SSID names in main.tf"
  type        = bool
  default     = false
}
