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
