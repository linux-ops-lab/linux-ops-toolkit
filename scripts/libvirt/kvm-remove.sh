#!/bin/bash

# Script to safely delete old KVMs

# Workflow
# 1. Show KVMs
# 2. Show KVM disks
# 3. Check KVM state
# 4. Show preflight summary
# 5. Gracefully shut down or forcefully stop KVM
# 6. Check KVM state again
# 7. Remove KVM from libvirt
# 8. Delete image files
# 9. Optionally remove virsh network
# 10. Check whether KVM was deleted

export LC_ALL=C
export LANG=C
unset LANGUAGE

TIMEOUT=120
INTERVAL=5
ELAPSED=0

mapfile -t KVM_ALL < <(virsh list --all --name | sed '/^$/d')
mapfile -t VIRSH_NET_ALL < <(virsh net-list --all --name | sed '/^$/d')

echo "__________________________________"
echo "Starting script to delete a KVM."
echo "__________________________________"
echo ""

#
# PRE-FLIGHT: KVM
#

echo "__________________________________"
echo "PRE-FLIGHT: KVM"
echo "__________________________________"
echo ""
echo "__________________________________"
echo "Overview of KVMs and virsh networks"
echo "__________________________________"
echo ""

pr -m -t -w 160 \
  <(
    echo "List of all KVMs on the KVM host:"
    echo "__________________________________"
    virsh list --all
  ) \
  <(
    echo "List of virsh networks:"
    echo "__________________________________"
    virsh net-list --all
  )

echo "__________________________________"

echo ""

read -p "Which KVM should be deleted? Please enter the full domain name / hostname: " KVM
echo "The following KVM will be deleted: $KVM"

if [[ -z "$KVM" ]]; then
  echo "No KVM specified. Exit."
  exit 1
fi

read -p "Continue? (y/n) " INPUT_1

if [[ "$INPUT_1" != "y" && "$INPUT_1" != "yes" ]]; then
  echo "Script aborted by user input. Exit."
  exit 0
fi

found="false"

for k in "${KVM_ALL[@]}"; do

  if [[ "$k" == "$KVM" ]]; then
    echo "KVM found."
    found="true"
    break
  fi

done

if [[ "$found" == "false" ]]; then
  echo "KVM not found."
  exit 1
fi

echo ""
echo "__________________________________"
echo ""
echo "Listing KVM details:"
echo "__________________________________"
virsh domblklist "$KVM" --details
KVM_BLK=$(virsh domblklist "$KVM" --details | awk '$1 == "file" && $2 == "disk" && $4 ~ /\.qcow2$/ {print $4}')

echo "KVM state: $(virsh domstate "$KVM")"
KVM_STATE=$(virsh domstate "$KVM")
echo "__________________________________"
echo ""

if [[ -z "$KVM_BLK" ]]; then
  echo "No qcow2 disk found for this KVM."
  echo "Please manually check the output of domblklist."
  exit 1
fi

echo ""
echo "The following image files were found:"
echo "$KVM_BLK"
echo ""

read -p "Continue with deletion? (y/n): " INPUT_2

if [[ "$INPUT_2" != "y" && "$INPUT_2" != "yes" ]]; then
  echo "Script aborted by user input. Exit."
  exit 0
fi

#
# PRE-FLIGHT: Optional virsh network
#

echo ""
echo "__________________________________"
echo "PRE-FLIGHT: Optional virsh network"
echo "Optional: Remove a virsh network that is no longer needed."
echo "Make sure beforehand that no other VM is using this network."
echo "__________________________________"
echo ""

read -p "Should the virsh networks related to the KVM also be removed? (y/n): " INPUT_3

if [[ "$INPUT_3" == "y" || "$INPUT_3" == "yes" ]]; then

  echo ""
  echo "List of virsh networks:"
  echo "__________________________________"
  virsh net-list --all
  echo "__________________________________"
  echo ""

  read -p "Which virsh network should be deleted? Please enter the full network name: " VIRSH

  if [[ -z "$VIRSH" ]]; then
    echo "No virsh network specified. Exit."
    exit 1
  fi

  echo "The following network will be deleted: $VIRSH"
  echo ""
  echo "Please check before deleting:"
  echo "virsh dumpxml <VM_NAME> | grep \"<source network='$VIRSH'\""
  echo ""

  read -p "Continue? (y/n) " INPUT_4

  if [[ "$INPUT_4" != "y" && "$INPUT_4" != "yes" ]]; then
    echo "Script aborted by user input. Exit."
    exit 0
  fi

  found="false"

  for v in "${VIRSH_NET_ALL[@]}"; do

    if [[ "$v" == "$VIRSH" ]]; then
      echo "virsh network found."
      found="true"
      break
    fi

  done

  if [[ "$found" == "false" ]]; then
    echo "virsh network not found."
    exit 1
  fi

else
  echo "No virsh network will be removed."
fi

#
# PRE-FLIGHT: Summary
#

echo ""
echo "__________________________________"
echo "PRE-FLIGHT summary"
echo "__________________________________"
echo ""
echo "KVM:"
echo "$KVM"
echo ""
echo "KVM state:"
echo "$KVM_STATE"
echo ""
echo "KVM image files:"
echo "$KVM_BLK"
echo ""

if [[ "$INPUT_3" == "y" || "$INPUT_3" == "yes" ]]; then
  echo "virsh network:"
  echo "$VIRSH"
else
  echo "virsh network:"
  echo "No virsh network selected for deletion."
fi

echo ""
echo "__________________________________"
echo ""

read -p "Execute all deletion actions listed above now? (y/n) " INPUT_5

if [[ "$INPUT_5" != "y" && "$INPUT_5" != "yes" ]]; then
  echo "Script aborted by user input. Exit."
  exit 0
fi

#
# ACTION AREA: Stop KVM
#

echo ""
echo "__________________________________"
echo "ACTION: Shut down KVM"
echo "__________________________________"
echo ""

echo "Shutting down KVM: $KVM"
echo "EXEC: virsh shutdown $KVM"
virsh shutdown "$KVM"

while true; do
  KVM_STATE=$(virsh domstate "$KVM" 2>/dev/null)

  if [[ "$KVM_STATE" == "shut off" ]]; then
    echo "KVM is shut off."
    break
  fi

  if ((ELAPSED >= TIMEOUT)); then
    echo "Timeout reached. Forcing KVM shutdown: $KVM"
    echo "EXEC: virsh destroy $KVM"
    virsh destroy "$KVM"

    KVM_STATE=$(virsh domstate "$KVM" 2>/dev/null)

    if [[ "$KVM_STATE" == "shut off" ]]; then
      echo "KVM was forcefully shut off."
      break
    else
      echo "Error: KVM could not be shut off. Current state: $KVM_STATE"
      exit 1
    fi
  fi

  echo "Current state: $KVM_STATE - waiting..."
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

#
# ACTION AREA: Undefine KVM and delete image
#

echo ""
echo "__________________________________"
echo "ACTION: Remove VM from libvirt and delete KVM image file."
echo "__________________________________"
echo ""

echo "EXEC: virsh undefine $KVM --managed-save --snapshots-metadata --checkpoints-metadata --nvram"

if ! virsh undefine "$KVM" --managed-save --snapshots-metadata --checkpoints-metadata --nvram; then
  echo "Could not remove KVM from libvirt."
else
  echo "KVM successfully removed from libvirt."
fi

echo ""
echo "EXEC: rm -i $KVM_BLK"
echo ""

if ! rm -i "$KVM_BLK"; then
  echo "KVM image file could not be deleted."
else
  echo "KVM image file successfully deleted."
fi

#
# ACTION AREA: Optionally remove virsh network
#

if [[ "$INPUT_3" == "y" || "$INPUT_3" == "yes" ]]; then

  echo ""
  echo "__________________________________"
  echo "ACTION: Remove virsh network"
  echo "__________________________________"
  echo ""

  echo "EXEC: virsh net-autostart $VIRSH --disable"
  if ! virsh net-autostart "$VIRSH" --disable; then
    echo "Could not disable virsh network autostart. Exiting script."
    exit 4
  else
    echo "virsh network autostart successfully disabled."
  fi

  echo "EXEC: virsh net-destroy $VIRSH"
  if virsh net-destroy "$VIRSH" 2>/dev/null; then
    echo "virsh network successfully stopped."
  else
    echo "virsh network could not be stopped or was already inactive."
  fi

  echo "EXEC: virsh net-undefine $VIRSH"
  if ! virsh net-undefine "$VIRSH"; then
    echo "virsh network could not be undefined. Exiting script."
    exit 4
  else
    echo "virsh network successfully undefined."
  fi

fi

#
# FINAL CHECK
#

echo ""
echo "__________________________________"
echo "Final check"
echo "__________________________________"
echo ""

echo "Checking whether KVM still exists in virsh:"
virsh list --all | grep "$KVM"

if [[ "$INPUT_3" == "y" || "$INPUT_3" == "yes" ]]; then
  echo ""
  echo "Checking whether virsh network still exists:"
  virsh net-list --all | grep "$VIRSH"
fi

echo ""
echo "Script completed."