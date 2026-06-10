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

variable "cfssl_instance" {
  type = object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  })
  default = null
}

variable "cfssl_instance_core_count" {
  description = "Number of VM cores to allocate for cfssl instance"
  default     = 2
}

variable "cfssl_instance_memory" {
  description = "Memory size to allocate for cfssl instance VM in MB"
  default     = 8192
}

variable "cfssl_ignition_systemd" {
  type        = list(string)
  description = "The systemd files to provide to the cfssl."
}

variable "cfssl_ignition_files" {
  type        = list(string)
  description = "The ignition files to provide to the cfssl."
}

variable "cfssl_ignition_directories" {
  type        = list(string)
  description = "The ignition directories to provide to the cfssl."
}

variable "etcd_instance_list" {
  type = list(object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  }))
  default = []
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

variable "etcd_subnet_cidr" {
  description = "Address range for etcd members for iptables rules"
}

variable "masters_subnet_cidr" {
  description = "Address range for master nodes for iptables rules"
}

variable "master_instance_list" {
  type = list(object({
    ip_address  = string
    mac_address = string
    pve_host    = string
  }))
  default = []
}

variable "master_instance_core_count" {
  description = "Number of VM cores to allocate per master node"
  default     = 8
}

variable "master_instance_memory" {
  description = "Memory size to allocate for master VMs in MB"
  default     = 32768
}


variable "master_ignition_systemd" {
  type        = list(string)
  description = "The systemd files to provide to master nodes."
}

variable "master_ignition_files" {
  type        = list(string)
  description = "The ignition files to provide to master nodes."
}

variable "master_ignition_directories" {
  type        = list(string)
  description = "The ignition directories to provide to master nodes."
}

variable "worker_instance_core_count" {
  description = "Default number of VM cores per worker node, used when a group does not set core_count."
  default     = 8
}

variable "worker_instance_memory" {
  description = "Default memory in MB per worker node, used when a group does not set memory."
  default     = 65536
}

variable "worker_groups" {
  type = map(object({
    instances = list(object({
      ip_address  = string
      mac_address = string
      pve_host    = string
    }))

    core_count           = optional(number)
    memory               = optional(number)
    disk_size            = optional(number, 50)
    ignition_systemd     = optional(list(string))
    ignition_files       = optional(list(string))
    ignition_directories = optional(list(string))
  }))
  default     = {}
  description = "Worker node groups keyed by name. Use 'default' for regular workers. All fields except instances fall back to the worker_instance_* and worker_ignition_* defaults when not set. Taints and labels are configured in tf_kube_ignition."
}

variable "worker_ignition_systemd" {
  type        = list(string)
  description = "Default systemd units for worker nodes, used when a group does not set ignition_systemd."
}

variable "worker_ignition_files" {
  type        = list(string)
  description = "Default ignition files for worker nodes, used when a group does not set ignition_files."
}

variable "worker_ignition_directories" {
  type        = list(string)
  description = "Default ignition directories for worker nodes, used when a group does not set ignition_directories."
}

variable "ssh_address_range" {
  description = "Address range from which to allow ssh"
}

variable "nodes_subnet_cidr" {
  description = "Address range for kube slave nodes"
}

variable "cluster_subnet" {
  description = "Cluster ip subnet"
}

variable "zone_mapping" {
  type        = map(string)
  description = "How to map VMs deployed in pve hosts to Kubernetes topology zones"

  default = {
    "pve-00" = "ld7-a"
    "pve-01" = "ld7-b"
    "pve-02" = "ld7-c"
    "pve-03" = "ld7-a"
    "pve-04" = "ld7-b"
    "pve-05" = "ld7-c"
    "pve-06" = "ld7-a"
    "pve-07" = "ld7-b"
    "pve-08" = "ld7-c"
    "pve-09" = "ld7-a"
    "pve-10" = "ld7-b"
    "pve-11" = "ld7-c"
  }
}

locals {
  # Mater hostnames are also calculated the same way under our Ansible
  # configuration for DHCP:
  # https://github.com/utilitywarehouse/sys-ansible-k8s-on-prem/blob/master/roles/dhcp/templates/dhcp.conf.tmpl
  master_hostname_list = [for master in var.master_instance_list : "master-${substr(sha256(master.mac_address), 0, 6)}"]

  # All worker instances across all groups in a single map keyed by hostname.
  # Hostname formula matches Ansible DHCP config:
  # https://github.com/utilitywarehouse/sys-ansible-k8s-on-prem/blob/master/roles/dhcp/templates/dhcp.conf.tmpl
  all_worker_instances = {
    for item in flatten([
      for group_name, group in var.worker_groups : [
        for instance in group.instances : {
          key                  = instance.ip_address
          hostname             = "${group_name}-${substr(sha256(instance.mac_address), 0, 6)}"
          ip_address           = instance.ip_address
          mac_address          = instance.mac_address
          pve_host             = instance.pve_host
          core_count           = coalesce(group.core_count, var.worker_instance_core_count)
          memory               = coalesce(group.memory, var.worker_instance_memory)
          disk_size            = group.disk_size
          ignition_systemd     = group.ignition_systemd != null ? group.ignition_systemd : var.worker_ignition_systemd
          ignition_files       = group.ignition_files != null ? group.ignition_files : var.worker_ignition_files
          ignition_directories = group.ignition_directories != null ? group.ignition_directories : var.worker_ignition_directories
          description          = "${group_name} node"
        }
      ]
    ]) : item.key => item
  }
}
