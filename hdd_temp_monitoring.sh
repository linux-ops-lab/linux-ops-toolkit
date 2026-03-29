#!/bin/bash

#Skript um die Temperatur von verschiedenen Festplatten zu überwachen
#und bei Überschreitung eines definierten Wertes eine E-Mail zu senden.

LOG="/var/log/hdd_temp.log"

declare -a HDD

mapfile -t HDD < <(lsblk | grep -Ev "[a-z]{3}[0-9]{1,2}" | cut -d " " -f1 | sed '/^$/d;/^NAME/d')

start_smartctl() {
    for H in "${HDD[@]}"; do
        echo "$(date) - Starte smartctl für Temepratur Monitoring für ${H}." | tee -a ${LOG}
        echo "____" | tee -a ${LOG}
        smartctl -A /dev/"${H}" | tee -a ${LOG}
        echo "" | tee -a ${LOG}
    done
}

read_smartctl() {
    for H in "${HDD[@]}"; do
        echo "Temperatur für ${H}: $(smartctl -a /dev/${H} | grep -i temperatur)" | tee -a ${LOG}
    done
}

alert() {
    for H in "${HDD[@]}"; do
        if [ "$(smartctl -A /dev/${H} | awk '/Temperature/ {print $10}')" -gt 50 ]; then
            echo "Temperaturwarnung für /dev/${H}: $(smartctl -a /dev/"${H}" | awk '/Temperature/ {print $10}') Grad" | mail -s "Temperaturwarnung für /dev/${H}: $(smartctl -a /dev/${H} | awk '/Temperature/ {print $10}')" root
            echo "$(date) - Alarm für /dev/${H} per Mail verschickt." | tee -a ${LOG}
        fi
    done
}

echo "_________________________________________________________________________" | tee -a ${LOG}
echo "$(date) - Starte Skript zur Temperaturüberwachung." | tee -a ${LOG}

#start_smartctl

#echo "" | tee -a ${LOG}

#sleep 180

echo "_________________________________________________________________________" | tee -a ${LOG}
echo "$(date) - Starte Auswertung der Temperatur: "|  tee -a ${LOG}
echo "_________________________________________________________________________" | tee -a ${LOG}
echo ""| tee -a ${LOG}

read_smartctl

echo ""| tee -a ${LOG}

alert

echo ""| tee -a ${LOG}

echo "$(date) - Skript abgeschlossen." | tee -a ${LOG}
echo "" | tee -a ${LOG}
