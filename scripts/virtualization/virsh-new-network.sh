#!/bin/bash

#Creates a new libvirt NAT network from a sanitized XML template, lets the operator review the generated definition, 
#and then defines and starts the network via virsh.

clear

TEMPLATE="HIER TEMPLATE XML PFAD ZUR TEMPLATE DATEI EINGEBEN"
TARGET="HIER OUTPUT PFAD EINGEBEN"

echo "_________________________"
echo "Starte Skript zur Anlage eines neuen Virsh-Netzwerks + neues Interface für eine KVM."
echo "_________________________"
echo ""

read -r -p "Fortfahren? (y/n): " CON 
echo ""

if [ "$CON" = "y" ] || [ "$CON" = "Y" ]; then
    echo "Bestätigt durch User - fahre mit Skript fort."
else
    echo "Skript durch User abgebrochen."
    exit 1
fi

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
echo "Bitte Stammdaten für neues Netzwerk eingeben:"
echo "_________________________"
echo ""

read -r -p "Networkname: (bspw. xyz_net): " name_net
read -r -p "Interface Nummer: (bspw. 123): " virbr_num
read -r -p "IP-Adresse: (bspw. 192.168.123.123): " ipv4

echo ""
echo "_________________________"
echo "Wiederhole Stammdaten:"
echo "_________________________"
echo ""

echo "Netzwerkname:         $name_net"
echo "Interface Nummer:     $virbr_num"
echo "IP-Adresse:           $ipv4"

echo ""
read -r -p "Fortfahren? (y/n): " CON2
echo ""

if [ "$CON2" = "y" ] || [ "$CON2" = "Y" ]; then
    echo "Stammdaten bestätigt - fahre mit Skript fort."
else
    echo "Skript durch User abgebrochen."
    exit 2
fi

echo ""
echo "_________________________"
echo "Kopiere template_net.xml nach $name_net.xml ..."

cp -p "$TEMPLATE" "$TARGET/${name_net}.xml"

if [ $? -eq 0 ]; then
    echo "${name_net}.xml erfolgreich erstellt."
else
    echo "${name_net}.xml konnte nicht erstellt werden."
    exit 3
fi
echo "_________________________"
echo ""

sed -i "s|name_net|$name_net|g" "$TARGET/${name_net}.xml"
sed -i "s|virbr_num|virbr$virbr_num|g" "$TARGET/${name_net}.xml"
sed -i "s|ipv4|$ipv4|g" "$TARGET/${name_net}.xml"

echo "Stammdaten in neue XML eingetragen."
echo ""

echo "_________________________"
echo "XML überprüfen:"
echo "_________________________"
echo ""

cat "$TARGET"/"$name_net".xml

echo ""

echo "_________________________"
echo ""

read -r -p "Fortfahren? (y/n): " CON3 
echo ""

if [ "$CON3" = "y" ] || [ "$CON3" = "Y" ]; then
    echo "XML durch User bestätigt - fahre mit Skript fort."
else
    echo "Skript durch User abgebrochen."
    exit 4
fi

echo ""
echo "Definiere Netzwerk in virsh, führe Setup durch ... "
echo ""

virsh net-define "$TARGET/${name_net}.xml" && \
virsh net-autostart "$name_net" && \
virsh net-start "$name_net" && \
virsh net-info "$name_net"

if [ $? -ne 0 ]; then
    echo "Netzwerk konnte in Virsh nicht definiert oder gestartet werden."
    echo "Skript abgebrochen."
    exit 5
else
    echo "Netzwerk erfolgreich definiert und gestartet."
fi
echo ""
