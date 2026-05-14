#!/bin/bash

# Purpose:
# Creates a new libvirt interface for an existing kvm
#
# Notes:
# - Intended as an interactive operator script
# - Uses a sanitized example template in the public repository

clear

echo "_________________________"
echo "Starte Skript zum hinzufügen eines Interfaces zu einer bestehenden KVM."
echo "_________________________"
echo ""

echo "_________________________"
echo "Auflistung aller Virsh-Netzwerke und Interfaces:"
echo "_________________________"
echo ""

for net_item in $(virsh net-list --all --name); do
    addr=$(virsh net-dumpxml "$net_item" | grep "<ip address" | sed -E "s/.*address='([^']+)'.*netmask='([^']+)'.*/\1 \2/")
    br=$(virsh net-dumpxml "$net_item" | grep "<bridge name" | sed -E "s/.*name='([^']+)'.*/\1/")
    printf "%-15s %-10s %-15s\n" "$net_item" "$br" "$addr"
done

echo ""
echo "_________________________"
echo "Auflistung aller virtuellen Maschinen:"
echo "_________________________"
echo ""

virsh list --all

echo ""
read -r -p "Welcher virtuellen Maschine soll ein Interface angehängt werden? (bspw. xyz-debian-01): " kvm
echo ""
echo "Ausgewählte KVM: $kvm"

echo ""
read -r -p "Welches Netzwerk soll der virtuellen Maschine $kvm angehängt werden? " net
echo ""
echo "Ausgewähltes Netzwerk: $net"

echo ""

read -r -p "Fortfahren? (y/n): " CON 
echo ""

if [ "$CON" = "y" ] || [ "$CON" = "Y" ]; then
    echo "Bestätigt durch User - fahre mit Skript fort."
else
    echo "Skript durch User abgebrochen."
    exit 1
fi

echo ""

if ! virsh dominfo "$kvm" >/dev/null 2>&1; then
    echo "Fehler: Die VM $kvm existiert nicht."
    exit 2
fi

if ! virsh net-info "$net" >/dev/null 2>&1; then
    echo "Fehler: Das Netzwerk $net existiert nicht."
    exit 3
fi

if virsh domiflist "$kvm" | awk -v net="$net" '$2 == "network" && $3 == net { found=1 } END { exit !found }'; then
    echo "Fehler: Die VM $kvm hat bereits ein Interface im Netzwerk $net."
    exit 4
fi

virsh attach-interface --domain "$kvm" --type network --source "$net" --model virtio --config --live

echo ""

if [ $? -eq 0 ]; then

    virsh domiflist "$kvm"

    echo ""

    echo "Interface für das Netzwerk $net an $kvm erfolgreich angehängt."
else
    echo "Interface für das Netzwerk $net konnte nicht an $kvm angehängt werden."
    exit 5
fi

echo ""
