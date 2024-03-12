resource "random_string" "worker_suffix" {
  count   = var.worker_count
  length  = 4
  special = false
  numeric = false
  upper   = false
  lower   = true

  # Keep string unique
  keepers = {
    unique_id = "${count.index}"
  }
}

resource "macaddress" "worker" {
  count = var.worker_count
}

locals {
  worker_list = flatten([
    for index, suffix in random_string.worker_suffix : {
      hostname = "worker-${suffix.id}"
      mac      = macaddress.worker[index].address
      ip       = cidrhost(var.worker_subnet_cidr, index)
    }
  ])
}

resource "matchbox_profile" "worker" {
  count  = var.worker_count
  name   = local.worker_list[count.index].hostname
  kernel = var.flatcar_kernel_address
  initrd = var.flatcar_initrd_addresses
  args = [
    "initrd=flatcar_production_pxe_image.cpio.gz",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "flatcar.first_boot=yes",
  ]

  raw_ignition = data.ignition_config.worker[count.index].rendered
}

resource "matchbox_group" "worker" {
  count = var.worker_count
  name  = local.worker_list[count.index].hostname

  profile = matchbox_profile.worker[count.index].name

  selector = {
    mac = local.worker_list[count.index].mac
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

# ToDo: There is no specific per worker config here to justify creating
# separate ignition files per worker. We'd need a way to have different
# zones here, so we can keep this configuratio as a placeholder
data "ignition_config" "worker" {
  count = var.worker_count

  systemd     = var.worker_ignition_systemd
  files       = var.worker_ignition_files
  directories = var.worker_ignition_directories
}

resource "proxmox_vm_qemu" "worker" {
  count       = var.worker_count
  name        = local.worker_list[count.index].hostname
  target_node = "proxmox-0"
  desc        = "Worker node"
  pxe         = true
  boot        = "order=net0;scsi0"
  cores       = 8
  hotplug     = "network,disk,usb"
  memory      = 32768
  vm_state    = "running"
  os_type     = "6.x - 2.6 Kernel"
  onboot      = true
  scsihw      = "virtio-scsi-pci"
  qemu_os     = "other"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = 50
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    bridge  = "vmbr0"
    macaddr = macaddress.worker[count.index].address
    model   = "virtio"
    tag     = var.vlan
  }

  depends_on = [
    null_resource.worker_restart_dhcpd,
  ]

}
