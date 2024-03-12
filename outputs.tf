output "worker_mac_address_list" {
  value = macaddress.worker.*.address
}
