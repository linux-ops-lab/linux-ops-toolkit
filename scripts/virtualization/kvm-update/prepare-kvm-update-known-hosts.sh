```bash
#!/usr/bin/env bash
set -euo pipefail

# Path to the dedicated known_hosts file used only for KVM update SSH connections.
KNOWN_HOSTS_FILE="/root/.ssh/known_hosts_kvm_update"

# Guest-specific setting: list all KVM guest IP addresses whose SSH host keys should be trusted for update automation.
HOST_IPS=(
    "192.168.10.7"
    "192.168.10.2"
    "192.168.2.3"
    "192.168.3.3"
    "192.168.4.3"
    "192.168.5.3"
    "192.168.10.3"
    "192.168.11.2"
    "192.168.12.2"
    "192.168.14.3"
    "192.168.17.2"
    "192.168.18.2"
)

echo ""
echo "Preparing known_hosts file for kvm update ssh connections."
echo "_______________________________________________"
echo ""

echo "EXEC: install -d -m 700 /root/.ssh"
install -d -m 700 /root/.ssh

echo "EXEC: touch $KNOWN_HOSTS_FILE"
touch "$KNOWN_HOSTS_FILE"

echo "EXEC: chmod 600 $KNOWN_HOSTS_FILE"
chmod 600 "$KNOWN_HOSTS_FILE"

# Iterate over all configured KVM guest IP addresses and refresh their ED25519 SSH host keys.
for ip in "${HOST_IPS[@]}"; do
    echo ""
    echo "Adding ED25519 host key for: $ip"
    echo "_______________________________________________"
    echo ""

    echo "INFO: Removing existing known_hosts entry for $ip if present."
    echo "EXEC: ssh-keygen -R $ip -f $KNOWN_HOSTS_FILE"
    ssh-keygen -R "$ip" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true

    echo "INFO: Scanning ED25519 host key for $ip."
    echo "EXEC: ssh-keyscan -t ed25519 -H $ip >> $KNOWN_HOSTS_FILE"

    # Add the current ED25519 SSH host key to the dedicated known_hosts file or abort on failure.
    if ! ssh-keyscan -t ed25519 -H "$ip" >> "$KNOWN_HOSTS_FILE" 2>/dev/null; then
        echo "ERROR: Could not scan ED25519 host key for $ip. Exit script."
        exit 1
    else
        echo "INFO: Host key added for $ip."
    fi
done

echo ""
echo "Setting final permissions."
echo "_______________________________________________"
echo ""

echo "EXEC: chmod 600 $KNOWN_HOSTS_FILE"
chmod 600 "$KNOWN_HOSTS_FILE"

echo ""
echo "DONE: Known hosts file prepared: $KNOWN_HOSTS_FILE"
```
