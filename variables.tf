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

variable "etcd_instance_list" {
  type = list(object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  }))
}

variable "etcd_instance_core_count" {
  description = "Number of VM cores to allocate per etcd instance"
  default     = 2
}

variable "etcd_instance_memory" {
  description = "Memory size to allocate for etcd instance VMs in MB"
  default     = 8192
}

variable "etcd_volume_size" {
  description = "Size of the persistent disk to back etcd store in GB"
  default     = 5
}

variable "etcd_ignition_systemd" {
  type        = list(list(string))
  description = "The systemd files to provide to the etcd members."
}

variable "etcd_ignition_files" {
  type        = list(list(string))
  description = "The ignition files to provide to the etcd members."
}

variable "etcd_ignition_directories" {
  type        = list(list(string))
  description = "The ignition directories to provide to the etcd members."
}

variable "worker_instance_list" {
  type = list(object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  }))
}

variable "worker_instance_core_count" {
  description = "Number of VM cores to allocate per worker node"
  default     = 8
}

variable "worker_instance_memory" {
  description = "Memory size to allocate for worker VMs in MB"
  default     = 32768
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
  # ETCD hostnames are also calculated the same way under our Ansible
  # configuration for DHCP:
  etcd_hostname_list = [for etcd in var.etcd_instance_list : "etcd-${substr(sha256(etcd.mac_address), 0, 6)}"]
  # Worker hostnames are also calculated the same way under our Ansible
  # configuration for DHCP:
  # https://github.com/utilitywarehouse/sys-ansible-k8s-on-prem/blob/master/roles/dhcp/templates/dhcp.conf.tmpl
  worker_hostname_list = [for worker in var.worker_instance_list : "worker-${substr(sha256(worker.mac_address), 0, 6)}"]
}
