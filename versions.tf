terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    proxmox = {
      source = "bpg/proxmox"
    }
    macaddress = {
      source  = "ivoronin/macaddress"
      version = "0.3.2"
    }
    ignition = {
      source = "community-terraform-providers/ignition"
    }
    matchbox = {
      source = "poseidon/matchbox"
    }
  }
}
