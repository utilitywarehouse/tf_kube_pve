# tf_kube_pve

This module holds Terraform configuration to boot Kubernetes cluster nodes on
ProxMox VMs.

As part of this configuration the following tasks will be managed:

- Creating/Updating DHCP config files for isc-dhcpd servers and restarting
  DHCP systemd services on passed nodes (ssh access needed).
- Create and update Matchbox groups and profiles to PXE boot new nodes
- Create ProxMox VMs.

## Adrdress Management

A part of this configuration is to manege MAC addresses generation for new
VMs and use them to update the passed DHCP servers to assign static IP
addresses within a ranges, as long as use them to match articular boot
configuration on Matchbox
