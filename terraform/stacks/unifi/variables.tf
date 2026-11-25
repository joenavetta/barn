variable "networks_enabled" {
  description = "Tagged networks (module.globals.networks keys) to create. Keep in step with stacks/opnsense networks_enabled"
  type        = list(string)
  default     = ["iot", "trusted", "guest", "cameras"]
}

variable "wlans_enabled" {
  description = "Create the SSIDs. Needs the unifi.wifi.home/iot/guest/cameras items in 1Password. An SSID is skipped until its network is in networks_enabled"
  type        = bool
  default     = true
}

variable "ssids" {
  description = "SSID names broadcast for each wireless network (keys match local.wlans in main.tf)"
  type = object({
    home    = string
    iot     = string
    guest   = string
    cameras = string
  })
  default = {
    home    = "cowshed"
    iot     = "cowshed-iot"
    guest   = "cowshed-guest"
    cameras = "cowshed-cameras"
  }
}
