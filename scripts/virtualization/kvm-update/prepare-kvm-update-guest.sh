#!/bin/bash

# Technical SSH user used by the host to trigger the guest update wrapper.
UPDATE_USER="kvm-update"

# Technical system group for the update user.
UPDATE_GROUP="kvm-update"

# Home directory for the technical update user.
USER_HOME="/var/lib/kvm-update"

# sshd drop-in configuration file that restricts the technical update user.
USER_SSHD_CONF="/etc/ssh/sshd_config.d/50-kvm-update.conf"

# sshd drop-in configuration file that disables direct root login.
ROOT_LOGIN_CONF="/etc/ssh/sshd_config.d/10-disable-root-login.conf"

# sudoers drop-in file that allows the technical update user to run only the update wrapper as root.
SUDOERS_FILE="/etc/sudoers.d/kvm-update"

# Authorized keys file for the technical update user.
AUTHORIZED_KEYS="$USER_HOME/.ssh/authorized_keys"

# Guest-specific setting: adjust this to the host or gateway IP as seen from this KVM guest.
KVM_HOST_GATEWAY_IP="192.168.4.1"

# Guest-specific setting: paste the public key from the KVM host that is allowed to trigger updates on this guest.
HOST_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEV4WZT2leeghJR+xnUaaQioq+f8iH5M93sq9ZyglB"

# Local path of the forced update wrapper executed through sudo.
UPDATE_WRAPPER="/usr/local/sbin/kvm-update-wrapper"

# Guest-specific setting: choose whether the guest should run zypper patch or zypper update.
UPDATE_MODE="patch"

# Guest-specific setting: restrict SSH key usage to source IPs matching the expected host-side network pattern.
FROM_PATTERN="192.168.*.1"

echo "Validating script input."
echo "_______________________________________________"
echo ""

# Ensure the setup script is executed with root privileges.
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be executed as root. Exit script."
    exit 1
fi

# Ensure that a host public key was configured before writing authorized_keys.
if [[ -z "$HOST_PUB_KEY" || "$HOST_PUB_KEY" == "x" ]]; then
    echo "ERROR: HOST_PUB_KEY is not set. Paste the public key from the host into HOST_PUB_KEY. Exit script."
    exit 2
fi

# Validate that the configured host public key looks like an ED25519 SSH public key.
if [[ ! "$HOST_PUB_KEY" =~ ^ssh-ed25519[[:space:]] ]]; then
    echo "ERROR: HOST_PUB_KEY does not look like an ed25519 public key. Exit script."
    exit 3
fi

# Validate that the configured update mode is supported by the update wrapper.
case "$UPDATE_MODE" in
    patch|update)
        echo "INFO: Update mode is valid: $UPDATE_MODE"
        ;;
    *)
        echo "ERROR: Unsupported UPDATE_MODE: $UPDATE_MODE. Allowed values are: patch, update. Exit script."
        exit 4
        ;;
esac

echo "INFO: Input validation passed."

echo ""
echo "Setting up sshd service."
echo "_______________________________________________"
echo ""
echo "INFO: Enable sshd service."
echo "EXEC: systemctl enable --now sshd.service."

# Enable and start the sshd service so the host can connect to this guest.
if ! systemctl enable --now sshd.service; then
    echo "ERROR: Could not activate sshd service. Check if service is installed. Exit script."
    exit 0;
else
    echo "INFO: sshd service enabled succesfully."
fi

echo ""
echo "Creating technical user in guest kvm."
echo "_______________________________________________"
echo ""

echo "INFO: Creating group for new user if missing: $UPDATE_GROUP."
echo "EXEC: groupadd --system $UPDATE_GROUP"

# Check whether the technical update group already exists before creating it.
if getent group "$UPDATE_GROUP" > /dev/null; then
    echo "INFO: Group already exists: $UPDATE_GROUP."
else
    # Create the technical system group if it does not exist yet.
    if ! groupadd --system "$UPDATE_GROUP"; then
        echo "ERROR: Could not create group: $UPDATE_GROUP. Exit script."
        exit 5
    else
        echo "INFO: Group succesfully added: $UPDATE_GROUP."
    fi
fi

echo "EXEC: useradd --system --create-home --home-dir $USER_HOME --shell /bin/bash --gid $UPDATE_GROUP $UPDATE_USER"

# Check whether the technical update user already exists before creating or adjusting it.
if id "$UPDATE_USER" > /dev/null 2>&1; then
    echo "INFO: User already exists: $UPDATE_USER."
    echo "INFO: Ensuring user settings are correct."
    echo "EXEC: usermod -g $UPDATE_GROUP -d $USER_HOME -s /bin/bash $UPDATE_USER"

    # Align the existing technical update user with the expected group, home directory, and shell.
    if ! usermod -g "$UPDATE_GROUP" -d "$USER_HOME" -s /bin/bash "$UPDATE_USER"; then
        echo "ERROR: Could not adjust existing technical update user. Exit script."
        exit 6
    else
        echo "INFO: Existing user adjusted succesfully: $UPDATE_USER."
    fi
else
    # Create the technical update user if it does not exist yet.
    if ! useradd --system --create-home --home-dir "$USER_HOME" --shell /bin/bash --gid "$UPDATE_GROUP" "$UPDATE_USER"; then
        echo "ERROR: Could not create technical update user. Exit script."
        exit 7
    else
        echo "INFO: User succesfully created: $UPDATE_USER."
    fi
fi

echo "INFO: Setting password lock for user. This prevents unauthorized password logins with this user."
echo "EXEC: passwd -l $UPDATE_USER"

# Lock the password of the technical update user to prevent password-based logins.
if ! passwd -l "$UPDATE_USER"; then
    echo "ERROR: Could not activate password lock for $UPDATE_USER. Exit script."
    exit 8
else
    echo "INFO: Password lock set succesfully for: $UPDATE_USER."
fi

echo "INFO: Ensuring home directory exists with correct ownership."
echo "EXEC: install -d -o $UPDATE_USER -g $UPDATE_GROUP -m 755 $USER_HOME"

# Create or correct the home directory with the expected owner, group, and permissions.
if ! install -d -o "$UPDATE_USER" -g "$UPDATE_GROUP" -m 755 "$USER_HOME"; then
    echo "ERROR: Could not prepare home directory: $USER_HOME. Exit script."
    exit 9
else
    echo "INFO: Home directory prepared succesfully: $USER_HOME."
fi

echo ""
echo "Prepare ssh directory for new created user: $UPDATE_USER"
echo "_______________________________________________"
echo ""

echo "EXEC: install -d -o $UPDATE_USER -g $UPDATE_GROUP -m 700 $USER_HOME/.ssh"

# Create the .ssh directory for the technical update user with restrictive permissions.
if ! install -d -o "$UPDATE_USER" -g "$UPDATE_GROUP" -m 700 "$USER_HOME"/.ssh; then
    echo "ERROR: Could not create directory $USER_HOME/.ssh. Exit script."
    exit 10
else
    echo "INFO: Directory $USER_HOME/.ssh created succesfully."
fi

echo "INFO: Creating authorized_keys file in users home .ssh directory."
echo "INFO: Public key will be restricted with forced command and source pattern."
echo "EXEC: cat > $AUTHORIZED_KEYS"

# Write the restricted SSH public key entry with a forced command and source address limitation.
if ! cat > "$AUTHORIZED_KEYS" <<EOF
command="sudo $UPDATE_WRAPPER",from="$FROM_PATTERN",restrict,no-agent-forwarding,no-X11-forwarding,no-port-forwarding,no-pty $HOST_PUB_KEY
EOF
then
    echo "ERROR: Could not write authorized_keys in users home .ssh directory. Exit script."
    exit 11
else
    echo "INFO: authorized_keys file written in users home .ssh directory."
fi

echo "INFO: Setting rights for authorized_keys file."
echo "EXEC: chown -R $UPDATE_USER:$UPDATE_GROUP $USER_HOME/.ssh"
echo "EXEC: chmod 700 $USER_HOME/.ssh"
echo "EXEC: chmod 600 $USER_HOME/.ssh/authorized_keys"

# Apply the required ownership and restrictive permissions to the SSH directory and authorized_keys file.
if ! { chown -R "$UPDATE_USER:$UPDATE_GROUP" "$USER_HOME/.ssh" && chmod 700 "$USER_HOME/.ssh" && chmod 600 "$AUTHORIZED_KEYS"; }; then
    echo "ERROR: Could not set rights properly. Exit script."
    exit 12
else
    echo "INFO: Rights set succesfully."
fi

echo ""
echo "Creating update script in guest."
echo "_______________________________________________"
echo ""

echo "INFO: Creating update wrapper file."
echo "EXEC: touch $UPDATE_WRAPPER"

# Create the local update wrapper file that will be executed by the forced SSH command.
if ! touch "$UPDATE_WRAPPER"; then
    echo "ERROR: Could not create update wrapper file. Exit script."
    exit 13
else
    echo "INFO: Update wrapper file created succesfully."

    # Write the update wrapper that refreshes repositories, installs updates, checks processes, and reboots the guest.
    if ! cat > "$UPDATE_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

UPDATE_MODE="$UPDATE_MODE"

# Validate the update mode before executing zypper.
case "\$UPDATE_MODE" in
    patch|update)
        ;;
    *)
        echo "ERROR: Unsupported UPDATE_MODE: \$UPDATE_MODE" >&2
        exit 2
        ;;
esac

/usr/bin/zypper --non-interactive refresh
/usr/bin/zypper --non-interactive "\$UPDATE_MODE" --auto-agree-with-licenses
/usr/bin/zypper ps -s || true
sleep 5
reboot now
EOF
    then
        echo "ERROR: Could not write update wrapper file. Exit script." >&2
        exit 14
    else
        echo "INFO: Update script pasted succesfully into update wrapper file."
        echo "INFO: Setting rights for update wrapper file."
        echo "EXEC: chown root:root $UPDATE_WRAPPER"
        echo "EXEC: chmod 750 $UPDATE_WRAPPER"

        # Restrict the update wrapper so it is owned by root and only executable by permitted users.
        if ! { chown root:root "$UPDATE_WRAPPER" && chmod 750 "$UPDATE_WRAPPER"; }; then
            echo "ERROR: Could not set rights for update wrapper file. Exit script."
            exit 15
        else
            echo "INFO: Rights for update wrapper file set succesfully."
        fi
    fi
fi

echo ""
echo "Setting sudoers rights for update wrapper."
echo "_______________________________________________"
echo ""

echo "INFO: Creating following file: $SUDOERS_FILE"
echo "EXEC: touch $SUDOERS_FILE"

# Create the sudoers drop-in file for the technical update user.
if ! touch "$SUDOERS_FILE"; then
    echo "ERROR: Could not create kvm-update sudoers file. Exit script."
    exit 16
else
    echo "INFO: sudoers file created succesfully."
    echo "INFO: Pasting input into new sudoers file."

    # Write the sudoers rule that allows the update user to run only the update wrapper without a password.
    if ! cat > "$SUDOERS_FILE" <<EOF
$UPDATE_USER ALL=(root) NOPASSWD: $UPDATE_WRAPPER
Defaults:$UPDATE_USER !requiretty
EOF
    then
        echo "ERROR: Could not paste input into kvm-update sudoers file. Exit script."
        exit 17
    else
        echo "INFO: Input into kvm-update sudoers file pasted succesfully."
        echo "INFO: Setting rights for sudoers file."
        echo "EXEC: chown root:root $SUDOERS_FILE"
        echo "EXEC: chmod 440 $SUDOERS_FILE"

        # Apply root ownership and read-only sudoers permissions to the sudoers drop-in file.
        if ! { chown root:root "$SUDOERS_FILE" && chmod 440 "$SUDOERS_FILE"; }; then
            echo "ERROR: Could not set rights for sudoers file. Exit script."
            exit 18
        else
            echo "INFO: Rights for sudoers file set succesfully."
        fi

        echo "INFO: Checking sudoers file for errors."
        echo "EXEC: visudo -cf $SUDOERS_FILE"

        # Validate the sudoers drop-in file before continuing.
        if ! visudo -cf "$SUDOERS_FILE"; then
            echo "ERROR: Error detected while checking new sudoers file. Exit script."
            exit 19
        else
            echo "INFO: New sudoers file is valid."
        fi
    fi
fi

echo ""
echo "Restricting sshd config for $UPDATE_USER."
echo "_______________________________________________"
echo ""

echo "INFO: Creating sshd config drop-in directory."
echo "EXEC: install -d -o root -g root -m 755 /etc/ssh/sshd_config.d"

# Ensure that the sshd drop-in directory exists before writing user-specific SSH restrictions.
if ! install -d -o root -g root -m 755 /etc/ssh/sshd_config.d; then
    echo "ERROR: Could not create sshd config drop-in directory. Exit script." >&2
    exit 20
else
    echo "INFO: sshd config drop-in directory exists: /etc/ssh/sshd_config.d"
fi

echo "INFO: Creating $USER_SSHD_CONF file."
echo "EXEC: touch $USER_SSHD_CONF"

# Create the sshd drop-in file for the technical update user.
if ! touch "$USER_SSHD_CONF"; then
    echo "ERROR: Could not create file: $USER_SSHD_CONF. Exit script."
    exit 21
else
    echo "INFO: sshd config file created succesfully: $USER_SSHD_CONF"
    echo "INFO: Putting config into new config file."

    # Write sshd restrictions that disable interactive and forwarding features for the update user.
    if ! cat > "$USER_SSHD_CONF" <<EOF
Match User $UPDATE_USER
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AllowTcpForwarding no
    X11Forwarding no
    AllowAgentForwarding no
    PermitTTY no
EOF
    then
        echo "ERROR: Could not create sshd config input. Exit script."
        exit 22
    else
        echo "INFO: sshd config created succesfully."
        echo "INFO: Setting ownership and permissions for $USER_SSHD_CONF."
        echo "EXEC: chown root:root $USER_SSHD_CONF"
        echo "EXEC: chmod 644 $USER_SSHD_CONF"

        # Apply root ownership and standard configuration file permissions to the update user sshd drop-in.
        if ! { chown root:root "$USER_SSHD_CONF" && chmod 644 "$USER_SSHD_CONF"; }; then
            echo "ERROR: Could not set rights for $USER_SSHD_CONF. Exit script."
            exit 23
        else
            echo "INFO: Rights for $USER_SSHD_CONF set succesfully."
        fi
    fi
fi

echo ""
echo "Disabling root login via sshd config."
echo "_______________________________________________"
echo ""

echo "INFO: Creating sshd config drop-in directory."
echo "EXEC: install -d -o root -g root -m 755 /etc/ssh/sshd_config.d"

# Ensure that the sshd drop-in directory exists before writing the root login restriction.
if ! install -d -o root -g root -m 755 /etc/ssh/sshd_config.d; then
    echo "ERROR: Could not create sshd config drop-in directory. Exit script." >&2
    exit 24
else
    echo "INFO: sshd config drop-in directory exists: /etc/ssh/sshd_config.d"
fi

echo "INFO: Creating $ROOT_LOGIN_CONF file."
echo "EXEC: touch $ROOT_LOGIN_CONF"

# Create the sshd drop-in file used to disable direct root login.
if ! touch "$ROOT_LOGIN_CONF"; then
    echo "ERROR: Could not create file: $ROOT_LOGIN_CONF. Exit script." >&2
    exit 25
else
    echo "INFO: sshd root login config file created successfully: $ROOT_LOGIN_CONF"
fi

echo "INFO: Setting ownership for $ROOT_LOGIN_CONF."
echo "EXEC: chown root:root $ROOT_LOGIN_CONF"

# Set root ownership for the root login sshd drop-in file.
if ! chown root:root "$ROOT_LOGIN_CONF"; then
    echo "ERROR: Could not set ownership for $ROOT_LOGIN_CONF. Exit script." >&2
    exit 26
else
    echo "INFO: Ownership set successfully for $ROOT_LOGIN_CONF."
fi

echo "INFO: Setting permissions for $ROOT_LOGIN_CONF."
echo "EXEC: chmod 644 $ROOT_LOGIN_CONF"

# Set standard read permissions for the root login sshd drop-in file.
if ! chmod 644 "$ROOT_LOGIN_CONF"; then
    echo "ERROR: Could not set permissions for $ROOT_LOGIN_CONF. Exit script." >&2
    exit 27
else
    echo "INFO: Permissions set successfully for $ROOT_LOGIN_CONF."
fi

echo "INFO: Putting root login restriction into sshd config file."

# Write the sshd directive that disables direct root login.
if ! cat > "$ROOT_LOGIN_CONF" <<'EOF'
PermitRootLogin no
EOF
then
    echo "ERROR: Could not write sshd root login config. Exit script." >&2
    exit 28
else
    echo "INFO: sshd root login config written successfully."
fi

echo "INFO: Validating content of $ROOT_LOGIN_CONF."

# Compare the written root login configuration with the expected content.
if cmp -s "$ROOT_LOGIN_CONF" - <<'EOF'
PermitRootLogin no
EOF
then
    echo "OK: $ROOT_LOGIN_CONF was created successfully and content is correct."
else
    echo "ERROR: $ROOT_LOGIN_CONF was created, but content does not match expected config. Exit script." >&2
    exit 29
fi

echo "INFO: Ensuring ssh host keys exist."
echo "EXEC: ssh-keygen -A"

# Generate missing SSH host keys if they are not already present.
if ! ssh-keygen -A; then
    echo "ERROR: Could not generate missing ssh host keys. Exit script." >&2
    exit 30
else
    echo "INFO: SSH host keys are available."
fi

echo "INFO: Testing sshd configuration syntax."
echo "EXEC: /usr/sbin/sshd -t"

# Validate sshd syntax before reloading the service.
if ! /usr/sbin/sshd -t; then
    echo "ERROR: sshd configuration syntax test failed. Exit script." >&2
    exit 30
else
    echo "INFO: sshd configuration syntax test passed."
fi

echo "INFO: Checking effective sshd configuration for root login."
echo "EXEC: /usr/sbin/sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -Fxq 'permitrootlogin no'"

# Verify that the effective sshd configuration disables root login.
if ! /usr/sbin/sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -Fxq "permitrootlogin no"; then
    echo "ERROR: Effective sshd config does not show 'PermitRootLogin no'." >&2
    echo "ERROR: Possible causes: drop-in directory is not included, or another sshd config entry has precedence." >&2
    exit 31
else
    echo "INFO: Effective sshd configuration confirms: PermitRootLogin no."
fi

echo "INFO: Checking effective sshd configuration for $UPDATE_USER."
echo "EXEC: /usr/sbin/sshd -T -C user=$UPDATE_USER,host=localhost,addr="$KVM_HOST_GATEWAY_IP""

EFFECTIVE_UPDATE_USER_CONF="$(/usr/sbin/sshd -T -C user="$UPDATE_USER",host=localhost,addr="$KVM_HOST_GATEWAY_IP")"

# Verify that password authentication is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "passwordauthentication no"; then
    echo "ERROR: Effective sshd config does not show 'PasswordAuthentication no' for $UPDATE_USER." >&2
    exit 32
else
    echo "INFO: Effective sshd configuration confirms: PasswordAuthentication no for $UPDATE_USER."
fi

# Verify that keyboard-interactive authentication is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "kbdinteractiveauthentication no"; then
    echo "ERROR: Effective sshd config does not show 'KbdInteractiveAuthentication no' for $UPDATE_USER." >&2
    exit 33
else
    echo "INFO: Effective sshd configuration confirms: KbdInteractiveAuthentication no for $UPDATE_USER."
fi

# Verify that TCP forwarding is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "allowtcpforwarding no"; then
    echo "ERROR: Effective sshd config does not show 'AllowTcpForwarding no' for $UPDATE_USER." >&2
    exit 34
else
    echo "INFO: Effective sshd configuration confirms: AllowTcpForwarding no for $UPDATE_USER."
fi

# Verify that X11 forwarding is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "x11forwarding no"; then
    echo "ERROR: Effective sshd config does not show 'X11Forwarding no' for $UPDATE_USER." >&2
    exit 35
else
    echo "INFO: Effective sshd configuration confirms: X11Forwarding no for $UPDATE_USER."
fi

# Verify that SSH agent forwarding is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "allowagentforwarding no"; then
    echo "ERROR: Effective sshd config does not show 'AllowAgentForwarding no' for $UPDATE_USER." >&2
    exit 36
else
    echo "INFO: Effective sshd configuration confirms: AllowAgentForwarding no for $UPDATE_USER."
fi

# Verify that TTY allocation is disabled for the technical update user.
if ! echo "$EFFECTIVE_UPDATE_USER_CONF" | grep -Fxq "permittty no"; then
    echo "ERROR: Effective sshd config does not show 'PermitTTY no' for $UPDATE_USER." >&2
    exit 37
else
    echo "INFO: Effective sshd configuration confirms: PermitTTY no for $UPDATE_USER."
fi

echo "INFO: Validating authorized_keys restrictions."

# Verify that authorized_keys contains the expected forced command.
if ! grep -Fq "command=\"sudo $UPDATE_WRAPPER\"" "$AUTHORIZED_KEYS"; then
    echo "ERROR: authorized_keys does not contain expected forced command. Exit script." >&2
    exit 38
else
    echo "INFO: authorized_keys contains expected forced command."
fi

# Verify that authorized_keys contains the expected source address restriction.
if ! grep -Fq "from=\"$FROM_PATTERN\"" "$AUTHORIZED_KEYS"; then
    echo "ERROR: authorized_keys does not contain expected from restriction. Exit script." >&2
    exit 39
else
    echo "INFO: authorized_keys contains expected from restriction."
fi

echo "INFO: Validating sudoers wrapper permission."

# Verify that the sudoers file contains the expected wrapper execution permission.
if ! grep -Fq "$UPDATE_USER ALL=(root) NOPASSWD: $UPDATE_WRAPPER" "$SUDOERS_FILE"; then
    echo "ERROR: sudoers file does not contain expected wrapper permission. Exit script." >&2
    exit 40
else
    echo "INFO: sudoers file contains expected wrapper permission."
fi

echo "INFO: Reloading sshd service."
echo "EXEC: systemctl reload sshd"

# Reload sshd so the new drop-in configuration becomes active.
if ! systemctl reload sshd; then
    echo "ERROR: Could not reload sshd service. Exit script." >&2
    exit 41
else
    echo "INFO: sshd service reloaded successfully."
fi

echo ""

echo "Setting up firewalld for ssh connections."
echo "_______________________________________________"
echo ""
echo "INFO: Allowing port 22 permanent in firewalld."
echo "EXEC: firewall-cmd --permanent --add-port=22/tcp"

# Permanently allow incoming SSH connections through firewalld.
if ! firewall-cmd --permanent --add-port=22/tcp; then
    echo "ERROR: Could not add ssh port to firewalld ruleset. Exit script."
    exit 42
else
    echo "INFO: Port 22 added succesfully to firewalld."
    echo "INFO: Refreshing firewalld."
    echo "EXEC: firewall-cmd --reload"

    # Reload firewalld so the permanent SSH rule becomes active.
    if ! firewall-cmd --reload; then
        echo "ERROR: Could not reload firewalld. Please reload it manually."
    else
        echo "INFO: firewalld reloaded succesfully."
    fi
fi

echo ""

echo "Printing guest ssh fingerprint for comparisson."
echo "_______________________________________________"
echo ""
echo "INFO: Printing guest ssh fingerprint:"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo ""

echo "DONE: Guest kvm is prepared for host based update automation."
