resource "matchbox_profile" "worker" {
  count  = length(var.worker_instance_list)
  name   = local.worker_hostname_list[count.index]
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
  count = length(var.worker_instance_list)
  name  = local.worker_hostname_list[count.index]

  profile = matchbox_profile.worker[count.index].name

  selector = {
    mac = var.worker_instance_list[count.index].mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

# ToDo: There is no specific per worker config here to justify creating
# separate ignition files per worker. We'd need a way to have different
# zones here, so we can keep this configuratio as a placeholder
data "ignition_config" "worker" {
  count = length(var.worker_instance_list)

  systemd     = var.worker_ignition_systemd
  files       = var.worker_ignition_files
  directories = var.worker_ignition_directories
}

resource "proxmox_vm_qemu" "worker" {
  count       = length(var.worker_instance_list)
  name        = local.worker_hostname_list[count.index]
  target_node = var.worker_instance_list[count.index].pve_host
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
    macaddr = var.worker_instance_list[count.index].mac_address
    model   = "virtio"
    tag     = var.vlan
  }
}
