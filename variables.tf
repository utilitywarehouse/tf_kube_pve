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

variable "dhcp_server_address_list" {
  description = "IP addresses to update dhcp config via ssh"
}

variable "vlan" {
  description = "The network vlan ID"
}

# proxmox_node_map is the map of the nodes to be deployed accross targets.
# An exampe configuration would be:
# variable "proxmox_node_map" = [
#   {
#     proxmox-0 = {
#       master_count = 1
#       worker_count = 3
#     }
#   },
#   {
#     proxmox-1 = {
#       worker_count = 9
#     }
#   }
# ]
variable "proxmox_node_map" {
  description = "A list of ProxMox target nodes and the number of noder per type (cfssl, etcd, master, worker) to deploy on each"

  type = list(map(object({
    cfssl_count  = optional(number, 0)
    etcd_count   = optional(number, 0)
    master_count = optional(number, 0)
    worker_count = optional(number, 0)
  })))

}
//variable "worker_count" {
//  description = "Number of vm's to create for worker nodes"
//}

variable "worker_subnet_cidr" {
  description = "Range for assigning worker IP addresses"
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
