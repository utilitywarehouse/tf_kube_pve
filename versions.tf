terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc1"
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
