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
userList="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
#userList="yoda tiger"
adminKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
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

for f in /etc/netplan/*.yaml; do
    if grep -q "$networkIPcidr" "$f"; then
        sed -i -e "s,${networkIPcidr},${newIPcidr},g" "$f"
    fi
done

# Edit the hosts file
sed -i -e "s,${networkIP},${newIP},g" "/etc/hosts"

# Apply the netplan
netplan apply

# Check Apache2 Status
if dpkg-query -W -f='${Status}' apache2 2> /dev/null | grep -q "install ok installed"; then
    apachestatus="Installed"
    echo "Apache Already Installed - Skipping..."
else
    apt-get install -y apache2 &> /dev/null


fi
# Check Squid. 
if dpkg-query -W -f='${Status}' squid 2> /dev/null | grep -q "install ok installed"; then
    squidstatus="Installed"
    echo "Squid Already Installed - Skipping..."
else
    echo "Installing Squid"
    apt-get install -y squid &> /dev/null
    

fi

# Enable the services regardless. Doesnt break if done if its already enabled.
systemctl enable --now squid &> /dev/null
systemctl enable --now apache2 &> /dev/null

# Users section

# Functions

# Add key to file 
function addAuthKeys {
    local key="$1"
    local file="$2"
    # -q for quiet we dont need output just the exit code | -x for the whole line, no partial matches
    # -F treat a string so no special characters are parsed

    # Check for the file, if not there create it
    if [ -f "$file" ]; then
        grep -qxF "$key" "$file" || { echo "$key" >> "$file"; echo "  Added a key to $file"; }
    else
        echo "  $file doesnt exist, not adding keys"
    fi

    

}

# Create SSH keys, does checks to see if the keys exist already and doesnt re-create. 
# Creates RSA and ED keys, checks if they exist first. 
# Takes user as argument #1. 


function createUserKeys {
    local sshdir="/home/$1/.ssh"
    mkdir -p "$sshdir"


    # Create ed25519
    if [ ! -f "$sshdir/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$sshdir/id_ed25519" -N "" -q -C "$1"
        echo "  Created ed25519 Key Pair"
    else
        echo "  ed25519 keypair already exists - skipping creation"
    fi

    # Create RSA
    if [ ! -f "$sshdir/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -f "$sshdir/id_rsa" -N "" -q -C "$1"
        echo "  Created RSA Key Pair"
    else
        echo "  RSA keypair already exists - skipping creation"
    fi

    
    # Add keys to authorized_keys

    if [ ! -f "$sshdir/authorized_keys" ]; then
        touch "$sshdir/authorized_keys"
        echo "  Created $sshdir/authorized_keys"
    fi 

    addAuthKeys "$(cat "$sshdir/id_ed25519.pub")" "$sshdir/authorized_keys"
    addAuthKeys "$(cat "$sshdir/id_rsa.pub")" "$sshdir/authorized_keys"

    # Set Permissions after everything is created. 
    chown -R "$1":"$1" "$sshdir"
    chmod 700 "$sshdir"
    chmod 600 "$sshdir/id_ed25519" "$sshdir/id_rsa"
    chmod 644 "$sshdir/id_ed25519.pub" "$sshdir/id_rsa.pub"

}

# Create Users from $userList. 
for u in $userList; do

    if id "$u" >/dev/null 2>&1; then
        echo "User $u already exists - skipping creation"
    else
        useradd -m -s /bin/bash "$u"
        echo "Created user: $u"
    fi

   
    # Create SSH keys
    createUserKeys "$u"

    # After Create as we need the keys to exist and directory to be created. 
    if [[ "$u" == "dennis" ]]; then
        usermod -aG sudo dennis
        addAuthKeys "$adminKey" "/home/$u/.ssh/authorized_keys"
    fi
done


#cat << EOF

#Apache2: $apachestatus
#Squid: $squidstatus

#Network Interface: $networkint
#Network IP CIDR: $networkIPcidr
#Network IP: $networkIP
#Netplan File: $netplanfile

#EOF

# Check squid Web proxy status

# Create Users accounts