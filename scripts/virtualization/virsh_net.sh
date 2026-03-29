#! /bin/bash

for NET in $(virsh net-list --all --name); do
    ADDR=$(virsh net-dumpxml "$NET" | grep "<ip address" | sed -E "s/.*address='([^']+)'.*netmask='([^']+)'.*/\1 \2/")
    BR=$(virsh net-dumpxml "$NET" | grep "<bridge name" | sed -E "s/.*name='([^']+)'.*/\1/")
    printf "%-15s %-10s %-15s\n" "$NET" "$BR" "$ADDR"
done

echo ""
