# Usage Examples

This document contains short example commands for the scripts included in this repository.
The examples are intentionally simple and are meant to show basic usage patterns only. Review each script before using it in a production environment. The repository currently includes RAM/process inspection, disk temperature monitoring, libvirt network overview, and libvirt firewall rule handling.    

## `ram_monitor.sh`

Shows the top memory-consuming processes on a Linux system, sorted by RSS. The script accepts an optional numeric argument that controls how many processes are shown. It also adds small contextual hints for selected process types such as QEMU guests and PHP-FPM pools. 

### Example

Run with the default number of entries:

./scripts/monitoring/ram_monitor.sh

Show the top 30 processes:

./scripts/monitoring/ram_monitor.sh 30

### Typical use case

Use this script when you want a quick overview of the current memory-heavy processes on a Linux host, for example during troubleshooting of high RAM usage or when identifying the largest consumers before deeper analysis. 

---

## `hdd_temp_monitoring.sh`

Reads disk temperature values via `smartctl`, writes status information to a log file, and can send an alert mail if a configured threshold is exceeded. The script relies on environment variables for log path, threshold, and alert recipient, with defaults built into the script. 

### Example

Run with default settings:

./scripts/monitoring/hdd_temp_monitoring.sh

Run with a custom threshold:

TEMP_THRESHOLD=45 ./scripts/monitoring/hdd_temp_monitoring.sh

Run with a custom log file and alert recipient:

LOG_FILE=/tmp/disk-temp.log MAIL_RECIPIENT=[admin@example.invalid](mailto:admin@example.invalid) ./scripts/monitoring/hdd_temp_monitoring.sh

### Typical use case

Use this script for basic hardware health monitoring on Linux systems where SMART data is available and where disk temperature should be logged or threshold breaches should trigger a simple alert. 

---

## `virsh_net.sh`

Prints an overview of available libvirt networks, including network name, bridge name, IP address, and netmask. The script reads network definitions through `virsh`. 

### Example

Show all available libvirt networks:

./scripts/virtualization/virsh_net.sh

### Typical use case

Use this script when you need a quick overview of the virtual network layout on a libvirt host, especially during lab setup, troubleshooting, or documentation work. 

---

## `libvirt-inter-vnet.sh`

Checks whether the libvirt firewall chains exist and inserts missing `iptables` rules that allow traffic to and from libvirt bridge interfaces such as `virbr*`. The script waits for the required chains and can be influenced through the `MAX_WAIT_SECONDS` environment variable. 

### Example

Run with default wait time:

sudo ./scripts/virtualization/libvirt-inter-vnet.sh

Run with a custom wait time:

sudo MAX_WAIT_SECONDS=60 ./scripts/virtualization/libvirt-inter-vnet.sh

### Typical use case

Use this script when working with libvirt-based virtual networks and you need to ensure that traffic between virtual bridge interfaces is not blocked due to missing libvirt-related `iptables` rules. Because it modifies firewall rules, it should be reviewed carefully before being used on a real system. 

---

## Notes

These examples are intentionally minimal. They are meant to illustrate how the scripts are executed, not to replace environment-specific validation, testing, or operational review. Some scripts are read-only helpers, while others actively interact with system components such as SMART data, libvirt network metadata, or `iptables` chains.    
