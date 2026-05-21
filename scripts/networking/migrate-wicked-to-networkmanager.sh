#!/bin/bash

# NetworkManager Migration Script
#
# This script prepares and migrates a selected network interface from wicked
# to NetworkManager on an openSUSE-based system.
#
# Workflow:
# 1. Display the current IP address configuration.
# 2. Ask the operator for the target interface, IP address, gateway, and prefix length.
# 3. Install NetworkManager.
# 4. Remove the legacy systemd network.service symlink if present.
# 5. Reload the systemd daemon.
# 6. Create a NetworkManager keyfile connection for the selected interface.
# 7. Stop and disable wicked if it is installed and active/enabled.
# 8. Remove wicked from the system.
# 9. Enable and start NetworkManager.
# 10. Reload NetworkManager connections.
# 11. Bring the new NetworkManager connection up.
#
# Intended use:
# This script is intended for controlled manual use by an administrator.
# It does not try to handle every possible edge case.

clear

# Configure script logging.
LOG_FILE="/var/log/wicked-networkmanager-migration.log"

# Create the log file if it does not exist and restrict access to root.
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Redirect stdout and stderr to the terminal and to the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

# Define the legacy network management tool and capture its current systemd state.
NETWORK_TOOL="wicked"
NETWORK_TOOL_SYSTEMD_STATE=$(systemctl is-enabled $NETWORK_TOOL)
NETWORK_TOOL_SYSTEMD_STATE2=$(systemctl is-active $NETWORK_TOOL)

echo ""
echo "======================================================================"
echo "NetworkManager migration started at: $(date -Is)"
echo "Log file: $LOG_FILE"
echo "======================================================================"
echo ""

# Display the current IP configuration so the operator can identify the correct interface.
echo "_______________________________________"
echo "Showing active IP address settings:"
echo "_______________________________________"
ip a
echo "_______________________________________"
echo ""

# Collect the required NetworkManager connection parameters from the operator.
read -p "Enter interface ID to migrate to NetworkManager (ex. enp...): " ID
read -p "Enter interface / device name to migrate to NetworkManager (eth...): " INTERFACE
read -p "Enter IP address to migrate to NetworkManager: " IP
read -p "Enter default gateway for the IP address above: " GATEWAY
read -p "Enter netmask / prefix length for the IP address above (example: 24): " NETMASK

echo ""

# Show a preflight summary before making changes to the network configuration.
echo "You are about to migrate the following interface to NetworkManager:"
echo "Interface: $INTERFACE"
echo "ID: $ID"
echo "IP: $IP/$NETMASK"
echo "Gateway: $GATEWAY"
echo ""
read -p "Continue? (y/n) " CON1

# Abort the script unless the operator explicitly confirms the migration.
if [[ "$CON1" != "y" && "$CON1" != "yes" ]]; then
  echo "Script canceled by user. Exiting now."
  exit 1
fi

# Generate a unique UUID for the new NetworkManager connection profile.
echo "Generating UUID for the new NetworkManager connection ..."
UUID=$(uuidgen)
echo "New UUID: $UUID"

echo ""

echo "_______________________________________"
echo "Setting up the network environment:"
echo "_______________________________________"

# Install NetworkManager before switching the active network management stack.
echo "INFO: Installing NetworkManager before migrating the selected interface."
echo "EXEC: zypper --non-interactive in NetworkManager -y"

echo ""

zypper --non-interactive in NetworkManager

if ! rpm -q NetworkManager; then
  echo "Could not install NetworkManager."
  echo "Please check the installation manually. Exiting script."
  exit 4
else
  echo "NetworkManager was installed successfully."
fi

# Remove the legacy network.service symlink so NetworkManager can become the active network service.
echo "INFO: Removing the legacy network.service symlink if it exists."
echo "EXEC: rm /etc/systemd/system/network.service"
if ! rm /etc/systemd/system/network.service; then
  echo "Could not remove the network.service symlink."
  echo "Please check this before activating NetworkManager."
else
  echo "The network.service symlink was removed successfully."
fi

# Reload systemd so it recognizes the changed service configuration.
echo "INFO: Reloading the systemd daemon after changing network service definitions."
echo "EXEC: systemctl daemon-reload"
if ! systemctl daemon-reload; then
  echo "Could not reload the systemd daemon."
  echo "Please check this manually."
else
  echo "The systemd daemon was reloaded successfully."
fi

echo "_______________________________________"
echo "Setting up the NetworkManager interface file:"
echo "_______________________________________"

# Create the NetworkManager keyfile connection for the selected interface.
cat >/etc/NetworkManager/system-connections/"$ID".nmconnection <<EOF
[connection]
id=$ID
uuid=$UUID
type=ethernet
interface-name=$INTERFACE
autoconnect=true

[ethernet]

[ipv4]
method=manual
address1=$IP/$NETMASK,$GATEWAY
dns=dns-opensuse-01.lan;
dns-search=lan;

[ipv6]
method=disabled

[proxy]
EOF

# Set ownership and permissions required by NetworkManager for system connection files.
echo "Setting ownership and file permissions for the new NetworkManager connection file."
chmod 600 /etc/NetworkManager/system-connections/"$ID".nmconnection
chown root:root /etc/NetworkManager/system-connections/"$ID".nmconnection
echo ""

# Check whether the legacy network management tool is installed.
echo "INFO: Checking whether the legacy network management tool is installed."
echo "EXEC: rpm -q $NETWORK_TOOL"
if ! rpm -q "$NETWORK_TOOL"; then
  echo "Could not find $NETWORK_TOOL on the system."
  echo "Continuing with the script."
else
  echo "Found $NETWORK_TOOL on the system."

  # Stop wicked if it is currently active.
  if [[ "$NETWORK_TOOL_SYSTEMD_STATE2" == "active" ]]; then
    echo "INFO: Stopping the active $NETWORK_TOOL service before enabling NetworkManager."
    echo "EXEC: systemctl stop $NETWORK_TOOL"
    if ! systemctl stop "$NETWORK_TOOL"; then
      echo "Could not stop the $NETWORK_TOOL service."
      echo "Please check the service. Exiting script."
      exit 2
    else
      echo "The $NETWORK_TOOL service was stopped successfully."
    fi
  fi

  # Disable wicked if it is currently enabled for automatic startup.
  if [[ "$NETWORK_TOOL_SYSTEMD_STATE" == "enabled" ]]; then
    echo "INFO: Disabling the $NETWORK_TOOL service to prevent it from starting automatically."
    echo "EXEC: systemctl disable --now $NETWORK_TOOL"
    if ! systemctl disable --now $NETWORK_TOOL; then
      echo "Could not disable $NETWORK_TOOL."
      echo "Please check the service. Exiting script."
      exit 2
    else
      echo "The $NETWORK_TOOL service was disabled successfully."
    fi
  fi
fi

# Remove the legacy network management package after it has been stopped and disabled.
echo "INFO: Removing the legacy network management package from the system."
echo "EXEC: zypper --non-interactive rm $NETWORK_TOOL -y"
zypper --non-interactive rm $NETWORK_TOOL

if rpm -q wicked; then
  echo "Could not remove $NETWORK_TOOL from the system."
  echo "Please check the uninstallation manually. Exiting script."
  exit 3
else
  echo "$NETWORK_TOOL was removed successfully from the system."
fi

# Enable and start NetworkManager as the active network management service.
echo "INFO: Enabling and starting the NetworkManager service."
echo "EXEC: systemctl enable --now NetworkManager"
if ! systemctl enable --now NetworkManager; then
  echo "Could not enable NetworkManager.service."
  echo "Please check this after the script."
else
  echo "NetworkManager.service was enabled successfully."
fi

# Reload systemd again after enabling NetworkManager.
echo "INFO: Reloading the systemd daemon after enabling NetworkManager."
echo "EXEC: systemctl daemon-reload"
if ! systemctl daemon-reload; then
  echo "Could not reload the systemd daemon."
  echo "Please check this manually."
else
  echo "The systemd daemon was reloaded successfully."
fi

# Restart NetworkManager
echo "INFO: Restarting NetworkManager."
echo "EXEC: systemctl restart NetworkManager."
systemctl restart NetworkManager

# Reload NetworkManager connection profiles so the new keyfile connection becomes available.
echo "INFO: Reloading NetworkManager connection profiles from disk."
echo "EXEC: nmcli connection reload"
if ! nmcli connection reload; then
  echo "Could not reload NetworkManager connections."
  echo "Reboot and try again."
else
  echo "NetworkManager connections were reloaded successfully."
fi

# Bring the newly created NetworkManager connection up.
echo "INFO: Activating the new NetworkManager connection for the selected interface."
echo "EXEC: nmcli connection up $ID"
if ! nmcli connection up "$ID"; then
  echo "Could not bring the new NetworkManager connection up."
  echo "Almost there. Check the logs for errors."
  echo "The script is finished anyway."
else
  echo "The new NetworkManager connection is up."
fi

# Remove remaining .service files of old network manager tool
if stat /etc/systemd/system/"$NETWORK_TOOL".service; then
  echo "Found old systemd unit file /etc/systemd/system/$NETWORK_TOOL.service"
  echo "INFO: Removing old systemd unit file."
  echo "EXEC: rm /etc/systemd/system/$NETWORK_TOOL.service"
  if ! rm /etc/systemd/system/"$NETWORK_TOOL".service; then
    echo "Could not remove old systemd unit file. Pleas check manually."
  else
    echo "Old systemd unit file succesfully removed."
  fi
fi

echo ""
echo "======================================================================"
echo "NetworkManager migration finished at: $(date -Is)"
echo "======================================================================"
echo ""
