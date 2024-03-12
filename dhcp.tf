# Copies DHCP config to servers and restarts the daemon

locals {
  matchbox_boot_location = "${var.matchbox_http_endpoint}/boot.ipxe"
}

# Workers
resource "null_resource" "worker_dhcp_copy" {
  count = length(var.dhcp_server_address_list)

  triggers = {
    config = templatefile("${path.module}/templates/workers_dhcp_config.tftpl", {
      worker_list            = local.worker_list
      dns_domain             = var.dns_domain
      matchbox_boot_location = local.matchbox_boot_location
    })
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/workers_dhcp_config.tftpl", {
      worker_list            = local.worker_list
      dns_domain             = var.dns_domain
      matchbox_boot_location = local.matchbox_boot_location
    })
    destination = "/etc/dhcp-exp/vm-workers.conf"
  }

  connection {
    host = var.dhcp_server_address_list[count.index]
    type = "ssh"
    user = "cumulus"
  }
}

resource "null_resource" "worker_restart_dhcpd" {
  count = length(var.dhcp_server_address_list)

  triggers = {
    config = templatefile("${path.module}/templates/workers_dhcp_config.tftpl", {
      worker_list            = local.worker_list
      dns_domain             = var.dns_domain
      matchbox_boot_location = local.matchbox_boot_location
    })
  }

  depends_on = [
    null_resource.worker_dhcp_copy # Restarting the server should come after the dhcp config is copied over
  ]

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart dhcp-exp.service"
    ]
  }

  connection {
    host = var.dhcp_server_address_list[count.index]
    type = "ssh"
    user = "cumulus"
  }
}
