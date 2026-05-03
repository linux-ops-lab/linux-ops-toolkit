#!/bin/bash

KVM_RUNNING=()
KVM_REBOOT_CHECK=()
KVM_NEXT_UPDATE_TIMER="5"

LOG_DIR="/var/log/kvm-update"
LOG_FILE="$LOG_DIR/$(basename "$0" .sh)_$(date +%Y-%m-%d_%H-%M-%S).log"

mkdir -p "$LOG_DIR"

exec >> "$LOG_FILE" 2>&1

mapfile -t KVM_RUNNING < <(virsh list --name)

echo "______________________________________________"
echo "Starting automated kvm update script."
echo "______________________________________________"
echo ""

# Iterate over all currently running KVM guests and trigger the update process for each entry.
for kvm in "${KVM_RUNNING[@]}"; do
    
    # Check whether the current KVM entry is not empty before running the update command.
    if [[ ! -z "$kvm" ]]; then
        echo "INFO: Updating kvm: $kvm."
        echo "EXEC: ssh $kvm-update"
        echo ""
        ssh "$kvm"-update
        echo ""
        echo "______________________________________________"
        echo "INFO: Update done. Rebooting kvm: $kvm."
        echo "INFO: Next update will start in $KVM_NEXT_UPDATE_TIMER seconds."
        sleep $KVM_NEXT_UPDATE_TIMER
    else
        echo "INFO: Empty entry."
    fi
done

echo ""

mapfile -t KVM_REBOOT_CHECK < <(virsh list --name)

# Iterate over the original list of updated KVM guests to verify whether each guest is running again.
for kvm_running in "${KVM_RUNNING[@]}"; do

    found="no"

     # Compare the current updated KVM guest against the list of guests running after the update process.
    for kvm_check in "${KVM_REBOOT_CHECK[@]}"; do

        # Check whether the updated KVM guest is present in the post-update running guest list.
        if [[ "$kvm_running" == "$kvm_check" ]]; then
            echo "Updated kvm rebooted succesfully: $kvm_running."
            found="yes"
        fi
    done

    # Report the KVM guest as failed if it was not found in the post-update running guest list.
    if [[ "$found" == "no" ]]; then
        echo "Updates kvm did not reboot succesfully: $kvm_running."
    fi

done

echo "______________________________________________"
echo "Update script finished."
echo "______________________________________________"
