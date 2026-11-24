variable "name" {
  type = string
}

variable "node" {
  description = "Proxmox node name, e.g. pve-01"
  type        = string
}

variable "vm_id" {
  type    = number
  default = null
}

variable "template_vm_id" {
  description = "VMID of the cloud-init template to clone"
  type        = number
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_gb" {
  type    = number
  default = 32
}

variable "datastore" {
  type    = string
  default = "local-zfs"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "ipv4_cidr" {
  description = "Static address in CIDR form, or \"dhcp\""
  type        = string
  default     = "dhcp"
}

variable "ipv4_gateway" {
  type    = string
  default = null
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "description" {
  type    = string
  default = null
}

variable "on_boot" {
  description = "Start the VM when the node boots"
  type        = bool
  default     = true
}

variable "dns_servers" {
  description = "Resolvers for a static address; empty keeps the template's"
  type        = list(string)
  default     = []
}

variable "dns_domain" {
  description = "Search domain set with dns_servers"
  type        = string
  default     = null
}

variable "user_data_file_id" {
  description = "Cloud-init user-data snippet (e.g. local:snippets/x.yaml). When set, ssh_public_keys is ignored; put the keys in the user-data"
  type        = string
  default     = null
}
