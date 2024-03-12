resource "cloudflare_record" "worker" {
  count   = length(local.worker_list)
  zone_id = var.dns_zone_id
  name    = local.worker_list[count.index].hostname
  value   = local.worker_list[count.index].ip
  type    = "A"
  ttl     = 120
}
