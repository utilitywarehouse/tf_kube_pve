resource "matchbox_profile" "cfssl" {
  name   = "cfssl-pve"
  kernel = var.flatcar_kernel_address
  initrd = var.flatcar_initrd_addresses
  args = [
    "initrd=flatcar_production_pxe_image.cpio.gz",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "flatcar.first_boot=yes",
    "root=LABEL=ROOT",
  ]

  raw_ignition = data.ignition_config.cfssl.rendered
}

resource "matchbox_group" "cfssl" {
  name    = "cfssl-pve"
  profile = matchbox_profile.cfssl.name

  selector = {
    mac = var.cfssl_instance.mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

// Firewall rules via iptables
data "ignition_file" "cfssl_iptables_rules" {
  path = "/var/lib/iptables/rules-save"
  mode = 420

  content {
    content = <<EOS
*filter
# Default Policies: Drop all incoming and forward attempts, allow outgoing
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
# Allow eveything on localhost
-A INPUT -i lo -j ACCEPT
# Allow all connections initiated by the host
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Allow ssh from jumpbox
-A INPUT -p tcp -m tcp -s "${var.ssh_address_range}" --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
# Allow etcds subnet to talk to cffsl
-A INPUT -p tcp -m tcp -s "${var.etcd_subnet_cidr}" --dport 8888 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.etcd_subnet_cidr}" --dport 8889 -j ACCEPT
# Allow masters subnet to talk to cffsl
-A INPUT -p tcp -m tcp -s "${var.masters_subnet_cidr}" --dport 8888 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.masters_subnet_cidr}" --dport 8889 -j ACCEPT
# Allow nodes subnet to talk to cfssl
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 8888 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 8889 -j ACCEPT
# Allow workers subnet to talk to node exporter
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 9100 -j ACCEPT
# Allow nodes subnet to talk to promtail for metrics
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 9080 -j ACCEPT
# Allow incoming ICMP for echo replies, unreachable destination messages, and time exceeded
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 0 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 3 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 8 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 11 -j ACCEPT
COMMIT
EOS

  }
}

// Get ignition config from the module
data "ignition_config" "cfssl" {
  disks = [
    data.ignition_disk.devsda.rendered,
  ]
  filesystems = [
    data.ignition_filesystem.root_scsi0.rendered,
  ]

  systemd = concat(
    [data.ignition_systemd_unit.iptables-rule-load.rendered],
    var.cfssl_ignition_systemd,
  )

  files = concat(
    [
      data.ignition_file.cfssl_iptables_rules.rendered,
    ],
    var.cfssl_ignition_files,
  )

  directories = var.cfssl_ignition_directories
}

resource "proxmox_vm_qemu" "cfssl" {
  name        = "cfssl"
  target_node = var.cfssl_instance.pve_host
  desc        = "CFSSL node"
  pxe         = true
  boot        = "order=net0"
  cores       = var.cfssl_instance_core_count
  hotplug     = "network,disk,usb"
  memory      = var.cfssl_instance_memory
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
    macaddr = var.cfssl_instance.mac_address
    model   = "virtio"
    mtu     = 9000
  }
}
