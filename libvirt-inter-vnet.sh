#!/bin/bash
set -euo pipefail

log() {
    echo "[libvirt-inter-vnet] $*"
}

# Warten, bis die libvirt-Chains existieren (max. 30 Sekunden)
for i in $(seq 1 30); do
    if iptables -L LIBVIRT_FWI -n &>/dev/null && iptables -L LIBVIRT_FWO -n &>/dev/null; then
        log "LIBVIRT_FWI und LIBVIRT_FWO gefunden."
        break
    fi
    log "Warte auf LIBVIRT_FWI / LIBVIRT_FWO (Versuch ${i}/30)..."
    sleep 1
done

if ! iptables -L LIBVIRT_FWI -n &>/dev/null || ! iptables -L LIBVIRT_FWO -n &>/dev/null; then
    log "LIBVIRT-Chains nicht gefunden, breche ab."
    exit 1
fi

# Regel 1: Alles, was ZU einem virbr-Interface geht, erlauben (eingehend Richtung VMs)
if iptables -C LIBVIRT_FWI -o virbr+ -j ACCEPT &>/dev/null; then
    log "Regel in LIBVIRT_FWI existiert bereits."
else
    log "Füge Regel in LIBVIRT_FWI ein: -o virbr+ -j ACCEPT"
    iptables -I LIBVIRT_FWI 1 -o virbr+ -j ACCEPT
fi

# Regel 2: Alles, was VON einem virbr-Interface kommt, erlauben (ausgehend von VMs)
if iptables -C LIBVIRT_FWO -i virbr+ -j ACCEPT &>/dev/null; then
    log "Regel in LIBVIRT_FWO existiert bereits."
else
    log "Füge Regel in LIBVIRT_FWO ein: -i virbr+ -j ACCEPT"
    iptables -I LIBVIRT_FWO 1 -i virbr+ -j ACCEPT
fi

log "Fertig."
