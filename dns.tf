resource "cloudflare_record" "worker" {
  count   = length(var.worker_instance_list)
  zone_id = var.dns_zone_id
  name    = local.worker_hostname[count.index]
  value   = var.worker_instance_list[count.index].ip_address
  type    = "A"
  ttl     = 120
}
