#!/bin/bash


# Script: System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: Script to determine modifications requried, runs on target system to make modifications and reports on changes made


# Variables

newIP=192.168.16.21/24
hostname="$(hostname)"

# Find the interface for the IP Specified
networkintid="192.168.16"
#networkint="$(ip route | grep $networkintid | awk '{print $3}')"

# Using IP command as route breaks if the checked IP is also the default route
# -o - one interface per line
# -4 - only check ipv4
# Then grep and awk, its always $2 this way and no issues with default route. The IP doesnt show as a network ID but actual IP so skip the last octet
networkint="$(ip -o -4 addr show | grep 192.168.16. | awk '{print $2}')"
networkIP="$(ip -o -4 addr show | grep 192.168.16. | awk '{print $4}')"

# Find The Yaml Fiiles that have the IP we are replacing
# It could be in multiple files, assuming we have to update all

for f in /root/netplan/*.yaml; do
    if grep -q "$networkIP" "$f"; then
        sed -i -e "s,${networkIP},${newIP},g" "$f"
    fi
done

# Returns the full path to the yaml file(s) that contains the network IP to be replaced
netplanfilefull="$(grep -l $networkIP /etc/netplan/*.yaml)"


# If it found the file then sed it. 

# Check Apache2 Status

#apachestatus="$(dpkg-query -W -f='${Status}' apache2 | awk '{print $3}')"
#quidstatus="$(dpkg-query -W -f='${Status}' squid | awk '{print $3}')"

if dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -q "install ok installed"; then
    apachestatus="Installed"
else
    apachestatus="Not Installed"

fi

if dpkg-query -W -f='${Status}' squid 2>/dev/null | grep -q "install ok installed"; then

    squidstatus="Installed"
else
    squidstatus="Not Installed"

fi

cat << EOF

Apache2: $apachestatus
Squid: $squidstatus

Network Interface: $networkint
Network IP: $networkIP
Netplan File: $netplanfile

EOF

# Check squid Web proxy status

# Create Users accounts