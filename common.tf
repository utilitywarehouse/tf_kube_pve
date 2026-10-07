# Specifies a root filesystem in case we are using the default ProxMox VirtIO
# SCSI controller
data "ignition_filesystem" "root_scsi0" {
  device          = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0"
  format          = "ext4"
  wipe_filesystem = true
  label           = "ROOT"
}

data "ignition_disk" "devsda" {
  device     = "/dev/sda"
  wipe_table = true

  partition {
    label  = "ROOT"
    number = 1
  }
}

data "ignition_systemd_unit" "iptables-rule-load" {
  name = "iptables-rule-load.service"

  content = <<EOS
[Unit]
Description=Loads presaved iptables rules from /var/lib/iptables/rules-save
[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /var/lib/iptables/rules-save
[Install]
WantedBy=multi-user.target
EOS
}

# Proxmox firewall for master and worker VMs. This replaces the Calico
# GlobalNetworkPolicies that used to protect the nodes. Env specific rules are
# defined by the caller as security groups and attached through
# master_extra_security_groups and worker_extra_security_groups.
#
# etcd and cfssl VMs keep their iptables rules shipped via ignition.

locals {
  firewall_trusted_sources = join(",", concat(
    [var.etcd_subnet_cidr, var.masters_subnet_cidr, var.nodes_subnet_cidr],
    var.firewall_trusted_cidrs,
  ))
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "node_base" {
  count = var.firewall_enabled ? 1 : 0

  name    = "node-base"
  comment = "Base rules for kube master and worker nodes"

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "icmp"
    comment = "allow-icmp"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = local.firewall_trusted_sources
    comment = "allow-all-internal-traffic"
  }

  # Calico failsafe ports, which no longer apply once the policies are gone.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = var.ssh_address_range
    comment = "allow-ssh"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "179"
    source  = join(",", var.firewall_bgp_source_cidrs)
    comment = "allow-bgp"
  }
}
