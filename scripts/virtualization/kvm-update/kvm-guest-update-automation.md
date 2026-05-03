# KVM Guest Update Automation

This folder contains a small Bash-based automation setup for patching and rebooting running KVM guests from a central KVM host.

The goal of this project is not to replace a full configuration management system such as Ansible, Salt, Puppet, or Uyuni. Instead, it demonstrates a lightweight, auditable, and security-conscious approach for controlled host-based update automation in a small virtualized Linux environment.

The scripts are designed around the following principles:

- use a dedicated technical SSH user for update automation
- restrict the SSH key to a single forced command
- prevent interactive shell access
- limit sudo permissions to one update wrapper only
- maintain a dedicated known_hosts file for automation
- log the complete update run on the KVM host
- reboot updated guests and verify whether they return to a running state

## Repository Scope

The setup consists of three scripts:

| Script | Purpose |
|---|---|
| Guest preparation script | Prepares each KVM guest for controlled update automation. |
| known_hosts preparation script | Collects and stores SSH host keys of all update targets in a dedicated known_hosts file. |
| Host update orchestration script | Detects running KVM guests, triggers their update process via SSH, and validates whether they are running again afterwards. |

## High-Level Architecture

The automation follows a host-to-guest model.

The KVM host is responsible for orchestration. It determines which virtual machines are currently running and connects to each guest through a dedicated SSH host alias ending in `-update`, for example:

`ssh mail-opensuse-01-update`

On the guest side, this SSH login does not open an interactive shell. Instead, the public key is bound to a forced command:

`sudo /usr/local/sbin/kvm-update-wrapper`

The wrapper then performs the actual update operation inside the guest and reboots the system afterwards.

This means the SSH key is not a general-purpose administration key. It is only useful for triggering the predefined update wrapper.

## Script 1: Guest Preparation Script

The guest preparation script is executed once on each KVM guest that should participate in the update automation.

Its main responsibilities are:

- create a dedicated technical update user
- create a dedicated technical update group
- lock password login for the technical update user
- create the `.ssh` directory and `authorized_keys` file
- write the host public key with forced-command restrictions
- create the update wrapper under `/usr/local/sbin/kvm-update-wrapper`
- grant passwordless sudo only for the update wrapper
- harden sshd settings for the update user
- disable direct root login via SSH
- validate the effective sshd configuration
- allow SSH through firewalld
- print the guest SSH host fingerprint for verification

### Important Guest-Specific Variables

The following variables usually need to be reviewed or adjusted per KVM guest:

| Variable | Description |
|---|---|
| `KVM_HOST_GATEWAY_IP` | The host or gateway IP address as seen from the guest. This is used when validating the effective sshd configuration for the update user. |
| `HOST_PUB_KEY` | The public SSH key from the KVM host that is allowed to trigger the update wrapper on the guest. |
| `UPDATE_MODE` | Defines whether the wrapper runs `zypper patch` or `zypper update`. Allowed values are `patch` and `update`. |
| `FROM_PATTERN` | Restricts from which source IP pattern the SSH key may be used. |
| `UPDATE_USER` | Technical update user. Usually the same on all guests. |
| `UPDATE_GROUP` | Technical update group. Usually the same on all guests. |
| `USER_HOME` | Home directory of the technical update user. |
| `UPDATE_WRAPPER` | Local wrapper command that is executed through the forced SSH command. |

### Security Model on the Guest

The guest-side security model uses multiple layers.

First, the technical user is not intended for interactive administration. The account exists only to receive a specific SSH key and trigger one specific operation.

Second, the authorized key is restricted with a forced command. Even if the host tries to execute a different SSH command, the guest will execute only the configured wrapper.

Third, additional SSH features are disabled for this user. This includes TTY allocation, TCP forwarding, X11 forwarding, and SSH agent forwarding.

Fourth, sudo is restricted to exactly one command: the update wrapper. The technical user does not receive general root privileges.

Fifth, direct root login via SSH is disabled to reduce the attack surface.

This layered design is important because no single control should be treated as sufficient on its own.

## Script 2: Dedicated known_hosts Preparation Script

The known_hosts preparation script runs on the KVM host.

Its purpose is to prepare a dedicated known_hosts file for automated update connections:

`/root/.ssh/known_hosts_kvm_update`

Instead of relying on the default root known_hosts file, the automation uses a separate file. This keeps update automation trust data isolated and easier to audit.

The script performs the following actions:

- ensures `/root/.ssh` exists with restrictive permissions
- creates the dedicated known_hosts file
- removes existing entries for each configured guest IP
- scans the current ED25519 SSH host key of each guest
- stores the scanned keys in hashed known_hosts format
- applies restrictive file permissions

### Important Variables

| Variable | Description |
|---|---|
| `KNOWN_HOSTS_FILE` | Path to the dedicated known_hosts file used by the update automation. |
| `HOST_IPS` | List of KVM guest IP addresses whose SSH host keys should be trusted. |

### Why a Dedicated known_hosts File?

A dedicated known_hosts file improves operational clarity.

It separates automation-specific SSH trust from normal interactive administration. This makes it easier to understand which host keys are required for the update process and avoids mixing automation state with unrelated root SSH sessions.

The host keys are stored in hashed format because `ssh-keyscan -H` is used. This is why entries look similar to:

`|1|...|... ssh-ed25519 AAAA...`

That is valid OpenSSH known_hosts syntax. The hash protects the clear-text hostname or IP from being directly visible in the file.

## Script 3: Host Update Orchestration Script

The host update orchestration script runs on the KVM host.

It uses `virsh list --name` to identify currently running KVM guests. Each running guest is then processed one after another.

For each running guest, the script calls the corresponding SSH update alias:

`ssh "$kvm"-update`

This assumes that the SSH client configuration on the host contains matching entries such as:

`Host mail-opensuse-01-update`

The update itself is not executed directly by the orchestration script. The orchestration script only triggers the guest-side forced command through SSH.

### Main Responsibilities

The host orchestration script performs the following tasks:

- create a timestamped log file under `/var/log/kvm-update`
- redirect all script output to the log file
- collect the list of currently running KVM guests
- trigger the update wrapper on each running guest through SSH
- wait a configurable number of seconds between guests
- collect the list of running guests again after the update run
- compare the original guest list with the post-update guest list
- report whether each updated guest appears to have rebooted successfully

### Important Variables

| Variable | Description |
|---|---|
| `KVM_RUNNING` | Array containing the running guests detected before the update run. |
| `KVM_REBOOT_CHECK` | Array containing the running guests detected after the update run. |
| `KVM_NEXT_UPDATE_TIMER` | Delay between update attempts for individual guests. |
| `LOG_DIR` | Directory where update logs are written. |
| `LOG_FILE` | Timestamped log file for the current script execution. |

## Operational Flow

A typical setup and execution flow looks like this:

1. Generate or select the SSH key on the KVM host that should be used for update automation.
2. Run the guest preparation script on each KVM guest.
3. Paste the host public key into the guest preparation script before running it.
4. Verify the printed SSH fingerprint of each guest.
5. Configure SSH host aliases on the KVM host with the `-update` suffix.
6. Run the known_hosts preparation script on the KVM host.
7. Run the host update orchestration script on the KVM host.
8. Review the generated log file under `/var/log/kvm-update`.

## Logging

The host orchestration script writes its complete output to a timestamped log file.

The log file path is built dynamically:

`/var/log/kvm-update/<script-name>_<timestamp>.log`

This makes each execution traceable and prevents older logs from being overwritten.

The logging approach is intentionally simple:

`exec >> "$LOG_FILE" 2>&1`

This redirects both standard output and standard error of the entire script into the log file.

## Update Modes

The guest wrapper supports two update modes:

| Mode | Command |
|---|---|
| `patch` | `zypper patch` |
| `update` | `zypper update` |

`patch` is usually the more conservative mode for regular maintenance because it applies official patches. `update` may update packages more broadly depending on repository state and package availability.

The correct choice depends on the operating model of the environment.

## Reboot Behavior

The guest update wrapper always reboots the guest after the update process.

This is intentional in this setup because the automation is designed around a clear maintenance flow:

1. apply updates
2. check processes that may still use old files
3. wait briefly
4. reboot
5. validate that the guest is running again

The host orchestration script does not currently perform deep service health checks after reboot. It only checks whether the guest appears in the `virsh list --name` output again.

For production-grade service validation, additional checks should be added, for example:

- SSH reachability after reboot
- systemd service status checks
- HTTP endpoint checks for web services
- database connectivity checks
- application-specific health checks
- monitoring integration with Prometheus, Grafana, Zabbix, or another monitoring system

## Assumptions

This automation assumes:

- the environment uses KVM/libvirt
- `virsh` is available on the KVM host
- guests are reachable via SSH from the host
- guests use systemd
- guests use OpenSSH server
- guests use `zypper`
- guests are allowed to reboot during the maintenance window
- SSH host aliases with the `-update` suffix exist on the host
- the guest-side forced command is properly configured
- the technical SSH key is protected on the host

## Security Considerations

This setup intentionally avoids giving the automation key unrestricted shell access.

Important security controls include:

- dedicated technical user
- locked password for the technical user
- forced SSH command
- source address restriction
- disabled TTY allocation
- disabled port forwarding
- disabled X11 forwarding
- disabled SSH agent forwarding
- sudo permission limited to one wrapper command
- direct root SSH login disabled
- dedicated known_hosts file
- ED25519 host key scanning
- sshd syntax validation before reload

Even with these controls, the host-side private key remains sensitive. Anyone with access to that private key and a matching source path may be able to trigger the update wrapper on prepared guests.

Therefore, the private key should be protected with strict filesystem permissions and should not be reused for unrelated administrative access.

## Limitations

This project is intentionally lightweight and has some limitations:

- it does not replace configuration management
- it does not perform package-level reporting
- it does not verify application health after reboot
- it does not handle complex dependency chains between guests
- it assumes that every updated guest should reboot
- it assumes that the VM name matches the SSH alias prefix
- it does not include rollback logic
- it does not include snapshot orchestration
- it does not notify external monitoring or alerting systems

These limitations are acceptable for a showcase and for controlled small-scale environments, but they should be reviewed before using this approach in a critical production environment.

## Possible Future Improvements

Potential improvements include:

- add a dry-run mode
- add pre-update and post-update hooks
- add service health checks after reboot
- add timeout handling for guests that do not return
- add dependency handling between application and database guests
- integrate ZFS snapshots before updates
- integrate monitoring alerts or maintenance windows
- write structured logs in JSON format
- add command-line parameters instead of editing variables in the script
- add shellcheck validation in CI
- add automated tests for parsing and validation logic

## Showcase Value

This project demonstrates several practical infrastructure engineering concepts:

- Bash scripting for operational automation
- KVM/libvirt-based guest discovery
- controlled SSH automation
- SSH forced-command design
- least-privilege sudo configuration
- sshd hardening with drop-in files
- dedicated known_hosts management
- timestamped operational logging
- basic reboot validation
- maintainable inline documentation

The most important design aspect is the separation of responsibilities:

- the host orchestrates
- SSH transports the trigger
- the guest restricts what can be executed
- sudo permits only the wrapper
- the wrapper owns the actual update logic

This makes the automation easier to reason about, audit, and extend.
