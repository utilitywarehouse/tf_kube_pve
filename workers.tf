resource "matchbox_profile" "worker" {
  for_each = local.all_worker_instances
  name     = each.value.hostname
  kernel   = var.flatcar_kernel_address
  initrd   = var.flatcar_initrd_addresses
  args = [
    "initrd=flatcar_production_pxe_image.cpio.gz",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "flatcar.first_boot=yes",
    "root=LABEL=ROOT",
  ]

  raw_ignition = data.ignition_config.worker[each.key].rendered
}

resource "matchbox_group" "worker" {
  for_each = local.all_worker_instances
  name     = each.value.hostname

  profile = matchbox_profile.worker[each.key].name

  selector = {
    mac = each.value.mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

data "ignition_file" "worker_kubelet_dropin" {
  for_each = local.all_worker_instances
  path     = "/etc/systemd/system/kubelet.service.d/local.conf"
  mode     = 420
  content {
    content = templatefile("${path.module}/resources/kubelet-dropin.conf",
      {
        labels = "role=worker,topology.kubernetes.io/zone=${var.zone_mapping[each.value.pve_host]}"
      }
    )
  }
}

data "ignition_config" "worker" {
  for_each = local.all_worker_instances

  directories = each.value.ignition_directories
  disks       = [data.ignition_disk.devsda.rendered]
  filesystems = [data.ignition_filesystem.root_scsi0.rendered]
  files = concat(
    [data.ignition_file.worker_kubelet_dropin[each.key].rendered],
    each.value.ignition_files
  )
  systemd = each.value.ignition_systemd
}

resource "proxmox_vm_qemu" "worker" {
  for_each    = local.all_worker_instances
  name        = each.value.hostname
  target_node = each.value.pve_host
  description = each.value.description
  pxe         = true
  boot        = "order=net0"
  cpu {
    cores = each.value.core_count
  }
  hotplug  = "network,disk,usb"
  memory   = each.value.memory
  vm_state = "running"
  os_type  = "6.x - 2.6 Kernel"
  onboot   = true
  scsihw   = "virtio-scsi-pci"
  qemu_os  = "other"

  # set emtpy tag to allow updates
  tags = ""

  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id      = 0
    bridge  = "vmbr0"
    macaddr = each.value.mac_address
    model   = "virtio"
    mtu     = 9000
  }

  # tags attribute keeps presenting diff between null and empty string values if
  # not set on terraform plan. Ignore since we are not using atm.
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
