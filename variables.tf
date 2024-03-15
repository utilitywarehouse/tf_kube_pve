variable "dns_zone_id" {
  description = "Clodflare zone id to create DNS records"
}

variable "dns_domain" {
  description = "Nodes addresses domain"
}

variable "matchbox_http_endpoint" {
  type        = string
  description = "Matchbox HTTP read-only endpoint (e.g. http://matchbox.example.com:8080)"
}

variable "proxmox_api_url" {
  type        = string
  description = "API endpoint to configure PVE"
}

variable "flatcar_kernel_address" {
  type        = string
  description = "Location of the http endpoint that serves the kernel vmlinuz file"
  default     = "http://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_pxe.vmlinuz"
}

variable "flatcar_initrd_addresses" {
  type        = list(string)
  description = "List of http endpoint locations the serve the flatcar initrd assets"
  default = [
    "http://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_pxe_image.cpio.gz",
  ]
}

variable "vlan" {
  description = "The network vlan ID"
}

variable "worker_instance_list" {
  type = list(object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  }))
}

variable "worker_ignition_systemd" {
  type        = list(string)
  description = "The systemd files to provide to worker nodes."
}

variable "worker_ignition_files" {
  type        = list(string)
  description = "The ignition files to provide to worker nodes."
}

variable "worker_ignition_directories" {
  type        = list(string)
  description = "The ignition directories to provide to worker nodes."
}

locals {
  # Worker histnames are also calculated the same way under our Ansible
  # configuration for DHCP:
  # https://github.com/utilitywarehouse/sys-ansible-k8s-on-prem/blob/master/roles/dhcp/templates/dhcp.conf.tmpl
  worker_hostname = [ for worker in var.worker_instance_list: "worker-${substr(sha256(worker.mac_address), 0, 6)}" ]
}
