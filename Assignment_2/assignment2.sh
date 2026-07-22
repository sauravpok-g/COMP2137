#!/bin/bash

# Script: System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: Script to determine modifications requried, runs on target system to make modifications and reports on changes made

# Variables
adminUsers="dennis"
userList="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
pkgList="apache2 squid"
#userList="yoda tiger"
adminKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

# IP/Interface we are searching for. 
networkintid="192.168.16"

# New IP Address to use, with CIDR
newIPcidr="192.168.16.21/24"
# Ip without the CIDR
newIP="$(echo "$newIPcidr" | cut -d/ -f1)"
intface="$(ip -o -4 addr show | grep "$networkintid" | awk '{print $2}')"
host="$(hostname)"


# Use IP command to get the current IP adddress used to replace in with CIDR
# -o - one interface per line
# -4 - only check ipv4
networkIPcidr="$(ip -o -4 addr show | grep "$networkintid" | awk '{print $4}')"
# Removed CIDR
networkIP="$(ip -o -4 addr show | grep "$networkintid" | awk '{print $4}' | cut -d/ -f1)"


# Find The Yaml Fiiles that have the IP we are replacing
# It could be in multiple files, assuming we have to update all
changed=0
echo "#### Updating NetPlan ####"
for f in /etc/netplan/*.yaml; do
    # Grep and check that its actually a new update
    if grep -q "$networkIPcidr" "$f" && [ "$networkIPcidr" != "$newIPcidr" ]; then
        echo "  Replacing $networkIPcidr with $newIPcidr in $f"
        sed -i -e "s,${networkIPcidr},${newIPcidr},g" "$f"
        changed=1
    fi
done

if [ "$changed" -eq 1 ]; then
    netplan apply && echo "  Applied netplan" || echo " ERROR: netplan apply failed"
else
    echo "  Network already $newIPcider - no changes"
fi


# Edit the hosts file
# Check for any NON loopback hostname lines
# Delete those lines and then append the correct IP HOSTNAME
# Check on hard hostname instead of IP incase its used for other things.

# Delete the existing line in the /etc/hosts file. 
# $host part matches lines mentioning the hostname, the ^127... deletes unless the line starts with 127 for loopbacks. 
# Ignoring IPV6 for now since assignment is all ipv4. 

# Check that it already exists before replacing. 
# Also check for any stale lines incase there is a stale line and a correct line. 
# Grep for all lines with hostname in host file | invert grep so it doesnt catch loopback | and invert grep the "correct" IP
# Will catch lines that are commented and will delete them, not a real issue. 
staleExists="$(grep "\b${host}\b" /etc/hosts | grep -v '^127\.' | grep -vxF "$newIP $host")"

echo "#### Updating /etc/hosts"
# x for whole line, -F for string no regex. And check that stale is empty. 
if grep -qxF "$newIP $host" /etc/hosts && [ -z "$staleExists" ]; then
    echo "  /etc/hosts already correct - no changes applied"
else
    # Strip bad lines, checks to that theres a space before the hostname and space or EOF after it (no matchings -XXX)
    sed -i "/[[:space:]]${host}\([[:space:]]\|$\)/{/^127\./!d}" /etc/hosts
    # Add new info to the file
    echo "$newIP $host" >> /etc/hosts
    echo "  updated /etc/hosts: $newIP $host"
fi


# Install Packages, use a loop for easier porting to command line args
# Pull packages from $pkgList. Check if isntalled, use install in the else to install and get the status of hte install for success.
# Otherwise its an error. 
echo "#### Package Check for: $pkgList ####"
for pkg in $pkgList; do
    if dpkg-query -W -f='${Status}' "$pkg" 2> /dev/null | grep -q "install ok installed"; then
        echo "  $pkg already installed - skipping"
    elif apt-get install -y "$pkg" &>/dev/null; then
        echo "  installed $pkg"
    else
        echo "  ERROR: failed to install $pkg"
    fi
    systemctl enable --now "$pkg" &> /dev/null && echo "  Enabled $pkg" || echo "  ERROR: Unable to enable $pkg"
done

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
        grep -qxF "$key" "$file" || { echo "$key" >> "$file"; echo "    Added a key to $file"; }
    else
        echo "    $file doesnt exist, not adding keys"
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
        echo "      Created ed25519 Key Pair"
    else
        echo "      ed25519 keypair already exists - skipping creation"
    fi

    # Create RSA
    if [ ! -f "$sshdir/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -f "$sshdir/id_rsa" -N "" -q -C "$1"
        echo "      Created RSA Key Pair"
    else
        echo "      RSA keypair already exists - skipping creation"
    fi

    
    # Add keys to authorized_keys

    if [ ! -f "$sshdir/authorized_keys" ]; then
        touch "$sshdir/authorized_keys"
        echo "      Created $sshdir/authorized_keys"
    fi 

    addAuthKeys "$(cat "$sshdir/id_ed25519.pub")" "$sshdir/authorized_keys"
    addAuthKeys "$(cat "$sshdir/id_rsa.pub")" "$sshdir/authorized_keys"

    # Set Permissions after everything is created. 
    chown -R "$1":"$1" "$sshdir"
    chmod 700 "$sshdir"
    chmod 600 "$sshdir/id_ed25519" "$sshdir/id_rsa" "$sshdir/authorized_keys"
    chmod 644 "$sshdir/id_ed25519.pub" "$sshdir/id_rsa.pub"

}

echo "#### Creating Users ####"
# Create Users from $userList. 
for u in $userList; do

    if id "$u" >/dev/null 2>&1; then
        echo "  User $u already exists - skipping creation"
    else
        useradd -m -s /bin/bash "$u"
        echo "  Created user: $u"
    fi

   
    # Create SSH keys
    createUserKeys "$u"

    # After Create as we need the keys to exist and directory to be created. 
    if [[ "$u" == "dennis" ]]; then
        usermod -aG sudo dennis
        addAuthKeys "$adminKey" "/home/$u/.ssh/authorized_keys"
    fi
done

# Exit with a success regardless of the outcome. 
exit 0