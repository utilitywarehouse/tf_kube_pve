output "etcd_data_volumeids" {
  value = [for e in var.etcd_instance_list : var.etcd_data_volume_id]
}
