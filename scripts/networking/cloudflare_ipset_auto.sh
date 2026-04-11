#!/bin/bash

#Script to add Cloudflare IPs automated without user interaction to firewalld's ipset

ipset4="cloudflare4"
ipset6="cloudflare6"

clear

mapfile -t ipv4_cidrs < <(
  curl -fsS https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv4_cidrs[]'
)

mapfile -t ipv6_cidrs < <(
  curl -fsS https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv6_cidrs[]'
)

echo "__________________________________________"
echo "Listing Cloudflare IPv4s:"
echo "__________________________________________"
echo

printf 'IPv4:\n'
printf '  %s\n' "${ipv4_cidrs[@]}"

echo ""
echo "__________________________________________"
echo "Listing Cloudflare IPv6s:"
echo "__________________________________________"
echo

printf 'IPv6:\n'
printf '  %s\n' "${ipv6_cidrs[@]}"

echo ""

for net in "${ipv4_cidrs[@]}"; do
        if ! firewall-cmd --permanent --ipset="$ipset4" --add-entry="$net"; then
                echo "Could not add $net to IPv4 ipset."
        else
                echo "$net added to IPv4 ipset."
        fi
done

for net in "${ipv6_cidrs[@]}"; do
        if ! firewall-cmd --permanent --ipset="$ipset6" --add-entry="$net"; then
                echo "Could not add $net to IPv6 ipset."
        else
                echo "$net added to IPv6 ipset."
        fi
done
