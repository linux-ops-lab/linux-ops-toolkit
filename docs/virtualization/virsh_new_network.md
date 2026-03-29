# Create libvirt network

This script creates a new libvirt network from an XML template and activates it with `virsh`. It is designed as an interactive helper for operators who want to build isolated NAT-based networks for KVM/libvirt guests without writing the full network definition by hand.

## What the script does

The script performs the following steps:

1. Lists existing libvirt networks, bridges, and address ranges for reference.
2. Prompts for the basic network parameters:
   - network name
   - bridge number
   - IPv4 gateway address
3. Copies a predefined XML template to a new file.
4. Replaces placeholder values inside the copied XML file.
5. Shows the generated XML for manual review.
6. Defines the network in libvirt.
7. Enables autostart for the network.
8. Starts the network.

## Requirements

- Linux host with KVM/libvirt
- `virsh`
- `sed`
- `grep`
- `awk`
- permissions to manage libvirt networks
- a valid network XML template file

## Template

The script expects a prepared XML template with placeholders that can be replaced during runtime.

Example placeholders:

- `net_name`
- `virbr_num`
- `ipv4`

## Safety notes

This script changes the libvirt network configuration of the host. Review the generated XML carefully before confirming the definition step.

Before using the script in production, verify at least the following:

* the selected network name does not already exist
* the bridge name is not already in use
* the chosen subnet does not overlap with existing libvirt or host networks
* the IPv4 address is valid and matches the intended subnet design

## Example use case

Typical use cases include:

* creating a dedicated network for a new application VM
* separating workloads into isolated NAT-based virtual networks
* preparing a network before attaching it to one or more guests

## What this script does not do automatically

The script does not fully validate all user input. In particular, operators should not assume that it automatically detects all conflicts related to:

* duplicate subnets
* invalid IP addressing
* bridge naming collisions
* environment-specific routing requirements

## Recommended workflow

A safe workflow is:

1. create the network with this script
2. review the resulting network in `virsh`
3. test connectivity expectations
4. attach the network to a VM in a separate step

## Related script

After the network has been created successfully, use the companion script to attach it to a VM:

docs/virtualization/virsh_new_interface.md
