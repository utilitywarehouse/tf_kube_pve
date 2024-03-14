resource "cloudflare_record" "worker" {
  count   = length(var.worker_instances)
  zone_id = var.dns_zone_id
  name    = "worker-pve-${count.index}"
  value   = var.worker_instances[count.index].ip_address
  type    = "A"
  ttl     = 120
}
