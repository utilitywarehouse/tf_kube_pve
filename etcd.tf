resource "matchbox_profile" "etcd" {
  count  = length(var.etcd_instance_list)
  name   = "etcd-pve-${count.index}"
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
  name  = "etcd-pve-${count.index}"

  profile = matchbox_profile.etcd[count.index].name

  selector = {
    mac = var.etcd_instance_list[count.index].mac_address
  }

  metadata = {
    ignition_endpoint = "${var.matchbox_http_endpoint}/ignition"
  }
}

# Firewall rules via iptables
data "ignition_file" "etcd_iptables_rules" {
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
# Allow etcds to talk
-A INPUT -p tcp -m tcp -s "${var.etcd_subnet_cidr}" --dport 2379 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.etcd_subnet_cidr}" --dport 2380 -j ACCEPT
# Allow masters subnet to talk to etcds
-A INPUT -p tcp -m tcp -s "${var.masters_subnet_cidr}" --dport 2379 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.masters_subnet_cidr}" --dport 2380 -j ACCEPT
# Allow nodes subnet to talk to etcds for metrics
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 9100 -j ACCEPT
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 9378 -j ACCEPT
# Allow nodes subnet to talk to vector for metrics
-A INPUT -p tcp -m tcp -s "${var.nodes_subnet_cidr}" --dport 8080 -j ACCEPT
# Allow docker default subnet to talk to etcds port 2379 for etcdctl-wrapper
-A INPUT -p tcp -m tcp -s 172.17.0.1/16 --dport 2379 -j ACCEPT
# Allow incoming ICMP for echo replies, unreachable destination messages, and time exceeded
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 0 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 3 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 8 -j ACCEPT
-A INPUT -p icmp -m icmp -s "${var.cluster_subnet}" --icmp-type 11 -j ACCEPT
COMMIT
EOS

  }
}

data "ignition_config" "etcd" {
  count = length(var.etcd_instance_list)

  directories = var.etcd_ignition_directories[count.index]
  filesystems = [
    data.ignition_filesystem.root_scsi0.rendered,
  ]
  files = concat(
    [
      data.ignition_file.etcd_iptables_rules.rendered,
    ],
    var.etcd_ignition_files[count.index],
  )
  systemd = concat(
    [
      data.ignition_systemd_unit.iptables-rule-load.rendered
    ],
    var.etcd_ignition_systemd[count.index],
  )

}

# disk ID based on the VM config below. Format and mounting will be done via
# the disk-mounter.service we ship with ignition. The variable is used to
# export the ID so that we can make it available to ignition module.
variable "etcd_data_volume_id" {
  default = "disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
}

resource "proxmox_vm_qemu" "etcd" {
  count       = length(var.etcd_instance_list)
  name        = "etcd-${count.index}"
  target_node = var.etcd_instance_list[count.index].pve_host
  desc        = "ETCD node"
  pxe         = true
  boot        = "order=net0"
  cpu {
    cores = var.etcd_instance_core_count
  }
  hotplug  = "network,disk,usb"
  memory   = var.etcd_instance_memory
  vm_state = "running"
  os_type  = "6.x - 2.6 Kernel"
  onboot   = true
  scsihw   = "virtio-scsi-pci"
  qemu_os  = "other"

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
    id      = 0
    bridge  = "vmbr0"
    macaddr = var.etcd_instance_list[count.index].mac_address
    model   = "virtio"
    mtu     = 9000
  }
}
