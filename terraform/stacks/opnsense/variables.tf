variable "trunk_parent" {
  description = "OPNsense NIC that carries the VLAN trunk to the switch: the LAN NIC that switch-01 plugs into (VP2420: igc0-igc3). Check Interfaces > Assignments"
  type        = string
  default     = "igc0" # LAN; igc1 is WAN
}

variable "networks_enabled" {
  description = "Tagged networks (module.globals.networks keys) whose VLAN devices exist. Add one at a time during the cutover"
  type        = list(string)
  default     = ["iot", "trusted", "guest", "cameras"]
}

# The OPNsense API can create VLAN devices but cannot assign them to interfaces.
# After the first apply, assign each vlan0.N under Interfaces > Assignments,
# enable it with the static .1 address from module.globals.networks, then put
# the identifiers it got (lan, opt1, ...) here. Rules are skipped until then.
variable "interfaces" {
  description = "Network key -> OPNsense interface identifier. Management is the untagged LAN."
  type        = map(string)
  #
  # Management (lan) is left out until the cutover: OPNsense's default
  # "LAN to any" rule keeps admin access to every VLAN until then, and adding
  # it here would put a block-everything-else rule on LAN.
  default = {
    iot     = "opt1" # vlan0.40, assigned 2026-11-24
    trusted = "opt2" # vlan0.20, assigned 2026-11-25
    cameras = "opt3" # vlan0.50, assigned 2026-11-25
    guest   = "opt4" # vlan0.60, assigned 2026-11-25
    # mgmt      = "lan"
    # servers, proxy, exitnode = "optN" as they move
    # tailscale = "optN"   # the tailscale0 device from the os-tailscale plugin
  }
}

variable "admin_devices" {
  description = "Trusted-VLAN addresses (DHCP reservations) of admin laptops/phones that may reach Management and Servers"
  type        = list(string)
  default     = []
}
