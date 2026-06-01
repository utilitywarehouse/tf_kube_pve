resource "cloudflare_record" "cfssl" {
  count   = var.cfssl_instance == null ? 0 : 1
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

resource "cloudflare_record" "etcd_all" {
  count   = length(var.etcd_instance_list)
  zone_id = var.dns_zone_id
  name    = "etcd"
  content = var.etcd_instance_list[count.index].ip_address
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "master" {
  count   = length(var.master_instance_list)
  zone_id = var.dns_zone_id
  name    = local.master_hostname_list[count.index]
  content = var.master_instance_list[count.index].ip_address
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "worker" {
  for_each = local.all_worker_instances
  zone_id  = var.dns_zone_id
  name     = each.key
  content  = each.value.ip_address
  type     = "A"
  ttl      = 120
}
