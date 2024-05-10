resource "matchbox_profile" "etcd" {
  count  = length(var.etcd_instance_list)
  name   = local.etcd_hostname_list[count.index]
  kernel = var.flatcar_kernel_address
  initrd = var.flatcar_initrd_addresses
  args = [
    "initrd=flatcar_production_pxe_image.cpio.gz",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "flatcar.first_boot=yes",
    "root=LABEL=ROOT",
  ]

  raw_ignition = data.ignition_config.etcd[count.index].rendered
}

resource "matchbox_group" "etcd" {
  count = length(var.etcd_instance_list)
  name  = local.etcd_hostname_list[count.index]

  profile = matchbox_profile.etcd[count.index].name

  selector = {
    mac = var.etcd_instance_list[count.index].mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

data "ignition_config" "etcd" {
  count = length(var.etcd_instance_list)

  directories = var.etcd_ignition_directories[count.index]
  disks = [
    data.ignition_disk.devsda.rendered,
  ]
  filesystems = [
    data.ignition_filesystem.root_scsi0.rendered,
  ]
  files   = var.etcd_ignition_files[count.index]
  systemd = var.etcd_ignition_systemd[count.index]
}

# disk ID based on the VM config below. Format and mounting will be done via
# the disk-mounter.service we ship with ignition. The variable is used to
# export the ID so that we can make it available to ignition module.
variable "etcd_data_volume_id" {
  default = "disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
}

resource "proxmox_vm_qemu" "etcd" {
  count       = length(var.etcd_instance_list)
  name        = local.etcd_hostname_list[count.index]
  target_node = var.etcd_instance_list[count.index].pve_host
  desc        = "Worker node"
  pxe         = true
  boot        = "order=net0"
  cores       = var.etcd_instance_core_count
  hotplug     = "network,disk,usb"
  memory      = var.etcd_instance_memory
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
      scsi1 {
        disk {
          size    = var.etcd_volume_size
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    bridge  = "vmbr0"
    macaddr = var.etcd_instance_list[count.index].mac_address
    model   = "virtio"
    mtu     = 9000
    tag     = var.vlan
  }
}
