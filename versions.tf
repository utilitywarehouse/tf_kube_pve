terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
    macaddress = {
      source = "ivoronin/macaddress"
      version = "0.3.2"
    }
    ignition = {
      source  = "community-terraform-providers/ignition"
    }
    matchbox = {
      source = "poseidon/matchbox"
    }
  }
}
