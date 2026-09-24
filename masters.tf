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
        labels = "role=master,topology.kubernetes.io/zone=${var.zone_mapping[var.master_instance_list[count.index].pve_host]}"
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

resource "proxmox_virtual_environment_vm" "master" {
  count         = length(var.master_instance_list)
  name          = local.master_hostname_list[count.index]
  node_name     = var.master_instance_list[count.index].pve_host
  description   = "Master node"
  tags          = ["master"]
  boot_order    = ["net0"]
  hotplug       = "network,disk,usb"
  on_boot       = true
  started       = true
  scsi_hardware = "virtio-scsi-pci"

  cpu {
    cores   = var.master_instance_core_count
    sockets = 1
    type    = "host" # inherited from telmate provider default value
  }

  memory {
    dedicated = var.master_instance_memory
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = 50
    file_format  = "raw"
    cache        = "none"
    discard      = "ignore"
    iothread     = false
    replicate    = false
    backup       = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = upper(var.master_instance_list[count.index].mac_address)
    model       = "virtio"
    mtu         = 9000
    firewall    = false
  }
}
