# Specifies a root filesystem in case we are using the default ProxMox VirtIO
# SCSI controller
data "ignition_filesystem" "root_scsi0" {
  device          = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0"
  format          = "ext4"
  wipe_filesystem = true
}
