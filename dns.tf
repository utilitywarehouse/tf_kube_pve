resource "cloudflare_record" "worker" {
  count   = var.worker_count
  zone_id = var.dns_zone_id
  name    = local.worker_list[count.index].hostname
  value   = local.worker_list[count.index].ip
  type    = "A"
  ttl     = 120
}
