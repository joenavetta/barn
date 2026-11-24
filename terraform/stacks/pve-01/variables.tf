variable "debian_template_vm_id" {
  description = "VMID of the Debian 13 cloud-init template on pve-01 (bin/barn-pve-cloud-template)"
  type        = number
  default     = 9000
}

variable "unifi_os_server_url" {
  description = "UniFi OS Server Linux x64 installer link from https://ui.com/download (Software > UniFi OS Server, copy link address)"
  type        = string

  validation {
    condition     = startswith(var.unifi_os_server_url, "https://fw-download.ubnt.com/")
    error_message = "Use the fw-download.ubnt.com link from ui.com/download."
  }
}

variable "unifi_os_server_sha256" {
  description = "SHA-256 of the installer, from the download page. Empty skips the check"
  type        = string
  default     = ""
}
