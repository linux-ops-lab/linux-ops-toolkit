# Design Notes

This repository contains small, focused Bash utilities derived from practical administration tasks. The included scripts cover four main areas: process and memory inspection, disk temperature monitoring, libvirt network overview, and libvirt-related firewall rule handling.    

## General Design Goals

The repository follows a few simple goals:

* keep scripts small and easy to understand
* solve a concrete operational task per script
* prefer readability over abstraction
* avoid unnecessary dependencies
* make public examples safe to share
* keep environment-specific details out of the public version

These scripts are not intended to be a large automation framework. They are meant to demonstrate pragmatic scripting for real administration scenarios in a way that remains understandable to other operators. The public versions are intentionally sanitized and generalized.

## Script Categories

### Monitoring and Inspection

`ram_monitor.sh` and `hdd_temp_monitoring.sh` fall into the monitoring and inspection category. One focuses on process memory usage and process context, while the other focuses on hardware temperature checks using SMART data and optional alerting. Both scripts are designed to support quick operational visibility with minimal setup.  

### Virtualization and Network Helpers

`virsh_net.sh` and `libvirt-inter-vnet.sh` focus on libvirt-related administration tasks. One provides a compact network overview, while the other actively checks and inserts firewall rules required for traffic around libvirt bridge interfaces. This separation reflects a deliberate distinction between read-only inspection helpers and scripts that change system state.  

## Operational Philosophy

The repository is built around simple helpers that are easy to inspect before use. That is particularly important because the scripts differ in operational impact:

* `ram_monitor.sh` is primarily observational
* `virsh_net.sh` is also observational
* `hdd_temp_monitoring.sh` reads SMART data and may send alert mail
* `libvirt-inter-vnet.sh` modifies `iptables` state

This distinction matters because not every script in a shell repository should be treated as equally safe or equally invasive. Clear intent and predictable scope are therefore part of the design.    

## Why the Repository Is Structured This Way

The repository is grouped by function rather than by script age or source. Monitoring-related scripts belong together because they address runtime visibility and host-state analysis. Virtualization-related scripts belong together because they deal with libvirt and virtual networking. This makes the repository easier to scan and easier to extend later with additional scripts of the same kind. The current structure also fits the fact that the included scripts naturally separate into monitoring and virtualization tasks.    

## Public-Safe Design

A core design principle of the public repository is sanitization. The public versions are meant to demonstrate technical approach, not to expose real hostnames, domains, internal storage layouts, or environment-specific operational details. That is especially relevant for infrastructure-oriented scripting, where raw production scripts often reveal more context than intended. The current public scripts are therefore presented as generalized examples rather than direct copies of a live environment.

## Trade-offs

These scripts intentionally do not try to solve every possible edge case. The focus is on direct usefulness, transparency, and easy review. That means there are trade-offs:

* limited abstraction
* minimal framework-like structure
* straightforward procedural flow
* explicit command usage instead of heavy wrapping layers

For showcase purposes, this is deliberate. Small administrative tools are often more valuable when their behavior is obvious at a glance than when they are heavily abstracted. The selected scripts reflect that approach through direct use of tools such as `ps`, `smartctl`, `virsh`, and `iptables`.    

## Future Direction

As the repository grows, additional scripts can be added if they meet the same basic standards:

* technically useful
* understandable without internal context
* safe to publish
* clearly scoped
* documented well enough for external readers

Possible future additions would fit best if they remain close to the current themes of Linux operations, monitoring, infrastructure helpers, and virtualization-related tooling. The current repository already establishes these areas as its main direction.    
