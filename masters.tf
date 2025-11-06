resource "matchbox_profile" "master" {
  count  = length(var.master_instance_list)
  name   = local.master_hostname_list[count.index]
  kernel = var.flatcar_kernel_address
  initrd = var.flatcar_initrd_addresses
  args = [
    "initrd=flatcar_production_pxe_image.cpio.gz",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "flatcar.first_boot=yes",
    "root=LABEL=ROOT",
  ]

  raw_ignition = data.ignition_config.master[count.index].rendered
}

resource "matchbox_group" "master" {
  count = length(var.master_instance_list)
  name  = local.master_hostname_list[count.index]

  profile = matchbox_profile.master[count.index].name

  selector = {
    mac = var.master_instance_list[count.index].mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

data "ignition_file" "master_kubelet_dropin" {
  count = length(var.master_instance_list)
  path  = "/etc/systemd/system/kubelet.service.d/local.conf"
  mode  = 420
  content {
    content = templatefile("${path.module}/resources/kubelet-dropin.conf",
      {
        labels = "role=master,topology.kubernetes.io/zone=${var.master_instance_list[count.index].pve_host}"
      }
    )
  }
}

data "ignition_config" "master" {
  count = length(var.master_instance_list)

  directories = var.master_ignition_directories
  filesystems = [
    data.ignition_filesystem.root_scsi0.rendered,
  ]
  files = concat(
    [
      data.ignition_file.master_kubelet_dropin[count.index].rendered,
    ],
    var.master_ignition_files
  )
  systemd = var.master_ignition_systemd
}

resource "proxmox_vm_qemu" "master" {
  count       = length(var.master_instance_list)
  name        = local.master_hostname_list[count.index]
  target_node = var.master_instance_list[count.index].pve_host
  desc        = "Worker node"
  pxe         = true
  boot        = "order=net0"
  cores       = var.master_instance_core_count
  hotplug     = "network,disk,usb"
  memory      = var.master_instance_memory
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
    macaddr = var.master_instance_list[count.index].mac_address
    model   = "virtio"
    mtu     = 9000
  }
}
