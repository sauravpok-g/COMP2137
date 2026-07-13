#!/bin/bash


# Script: System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: Script to determine modifications requried, runs on target system to make modifications and reports on changes made

# TO-DO
# 1. The Hosts replacement, searching for the same IP which may not actually be the right address
# 2. Potentially find a way to replace the interface's address itself instead of the addresss searching.
# 3. Make these into functions for adaptbility into A3, low priority. 


# Variables
adminUsers="dennis"
#userList="aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
userList="yoda"

# Interface we are searching for. 
networkintid="192.168.16"

# New IP Address to use, with CIDR
newIPcidr="192.168.16.21/24"
# Ip without the CIDR
newIP="$(echo "$newIPcidr" | cut -d/ -f1)"

hostname="$(hostname)"


# Use IP command to get the current IP adddress used to replace in with CIDR
# -o - one interface per line
# -4 - only check ipv4
networkIPcidr="$(ip -o -4 addr show | grep "$networkintid" | awk '{print $4}')"
# Removed CIDR
networkIP="$(ip -o -4 addr show | grep "$networkintid" | awk '{print $4}' | cut -d/ -f1)"


# Find The Yaml Fiiles that have the IP we are replacing
# It could be in multiple files, assuming we have to update all

for f in /root/netplan/*.yaml; do
    if grep -q "$networkIPcidr" "$f"; then
        sed -i -e "s,${networkIPcidr},${newIPcidr},g" "$f"
    fi
done

# Edit the hosts file
sed -i -e "s,${networkIP},${newIP},g" "/root/hosts"

# Check Apache2 Status
if dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -q "install ok installed"; then
    apachestatus="Installed"
else
    apachestatus="Not Installed"

fi
# Check Squid. 
if dpkg-query -W -f='${Status}' squid 2>/dev/null | grep -q "install ok installed"; then

    squidstatus="Installed"
else
    squidstatus="Not Installed"

fi


# Users section

# Functions

# Create SSH keys, does checks to see if the keys exist already and doesnt re-create. 
# Creates RSA and ED keys, checks if they exist first. 
# Takes user as argument #1. 

function createUserKeys {
    local sshdir="/home/$1/.ssh"

    mkdir -p "$sshdir"

    if [ ! -f "$sshdir/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$sshdir/id_ed25519" -N "" -q -C "$1"
    fi

    if [ ! -f "$sshdir/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -f "$sshdir/id_rsa" -N "" -q -C "$1"
    fi

    chown -R "$1":"$1" "$sshdir"
    chmod 700 "$sshdir"
    chmod 600 "$sshdir/id_ed25519" "$sshdir/id_rsa"
    chmod 644 "$sshdir/id_ed25519.pub" "$sshdir/id_rsa.pub"
    
}

# Create Users
for u in $userList; do
    if id "$u" >/dev/null 2>&1; then
        echo "User $u already exists - skipping creation"
    else
        sudo useradd -m -s /bin/bash "$u"
        echo "Created user: $u"
    fi

    createUserKeys "$u"
done

cat << EOF

Apache2: $apachestatus
Squid: $squidstatus

Network Interface: $networkint
Network IP CIDR: $networkIPcidr
Network IP: $networkIP
Netplan File: $netplanfile

EOF

# Check squid Web proxy status

# Create Users accounts