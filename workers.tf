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

  cpu {
    cores   = each.value.core_count
    sockets = 1
    type    = "host" # inherited from telmate provider default value
  }

  memory {
    dedicated = each.value.memory
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
    mac_address = upper(each.value.mac_address)
    model       = "virtio"
    mtu         = 9000
    firewall    = var.firewall_enabled
  }
}

resource "proxmox_virtual_environment_firewall_options" "worker" {
  for_each = var.firewall_enabled ? local.all_worker_instances : {}

  node_name     = proxmox_virtual_environment_vm.worker[each.key].node_name
  vm_id         = proxmox_virtual_environment_vm.worker[each.key].vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  # VMs PXE boot and get their address via DHCP
  dhcp = true
}

resource "proxmox_virtual_environment_firewall_rules" "worker" {
  for_each = var.firewall_enabled ? local.all_worker_instances : {}

  node_name = proxmox_virtual_environment_vm.worker[each.key].node_name
  vm_id     = proxmox_virtual_environment_vm.worker[each.key].vm_id

  dynamic "rule" {
    for_each = concat(
      [proxmox_virtual_environment_cluster_firewall_security_group.node_base[0].name],
      var.worker_extra_security_groups,
    )
    content {
      security_group = rule.value
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.worker]
}
