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

resource "proxmox_virtual_environment_vm" "worker" {
  for_each      = local.all_worker_instances
  name          = each.value.hostname
  node_name     = each.value.pve_host
  description   = each.value.description
  tags          = ["worker"]
  boot_order    = ["net0"]
  hotplug       = "network,disk,usb"
  on_boot       = true
  started       = true
  scsi_hardware = "virtio-scsi-pci"

  operating_system {
    type = "other"
  }

  cpu {
    cores   = each.value.core_count
    sockets = 1
    type    = "host" # inherited from telmate provider default value
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = false
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = each.value.disk_size
    file_format  = "raw"
    cache        = "none"
    discard      = "ignore"
    iothread     = false
    replicate    = false
    backup       = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac_address
    model       = "virtio"
    mtu         = 9000
    firewall    = false
  }
}
