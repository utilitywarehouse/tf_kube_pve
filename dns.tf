resource "cloudflare_record" "cfssl" {
  zone_id = var.dns_zone_id
  name    = "cfssl"
  content = var.cfssl_instance.ip_address
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "etcd" {
  count   = length(var.etcd_instance_list)
  zone_id = var.dns_zone_id
  name    = "etcd-${count.index}"
  content = var.etcd_instance_list[count.index].ip_address
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "worker" {
  count   = length(var.worker_instance_list)
  zone_id = var.dns_zone_id
  name    = local.worker_hostname_list[count.index]
  content = var.worker_instance_list[count.index].ip_address
  type    = "A"
  ttl     = 120
}
