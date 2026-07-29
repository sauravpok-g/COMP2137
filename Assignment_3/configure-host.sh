#!/bin/bash

# Script: Distributed System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: 
# Modified: Jul 22 11:00


# TO DO:
# Command line args
#   -verbose (DONE)
#   -name desiredName (done)
#   -ip desiredIPAddress (done)
#   -hostEntry desiredName desiredIP (done)
# 
# Error "Handling", no output unless verbose EXCEPT for errors (done)
# TERM, HUP, INT handling (done)

trap '' TERM HUP INT

# Track if we are in verbose
verbose=0

# internal log for any errors
errors=0

# Current Hostname for verbose
selfName="$(hostname)"

# My Echo function
# Checks to see if theres verbose and then prints
function myEcho () {
    [ "$verbose" -eq 1 ] && echo "[$selfName] $@"
}

# My Log Function
# Logs to system via logger with predefined args to keep it consistant.
function myLog () {
    logger -t "$(basename "$0")" -i -p user.warning -- "$@"
}

# My Error Function
# Handles errors in a custom way. Any errors are sent to stderr using this function and not echo'd normally. 
function myError () { 
    # Increment the error counter. Anything not 0 is an error.
    echo "$(basename "$0"): $*" >&2
    ((errors++))
}

# Change Hostname in both /etc/hosts and /etc/hostname
# Only update if theres a change. 
# Takes one arg: DesiredName
function changeHostname () {
    local desiredName="$1"
    local currentName="$(hostname)"
    # Static used to only check /etc/hostname
    local hostnameFile="$(hostnamectl --static hostname)"

    # If running hostname doesnt match, change it
    if [ "$currentName" != "$desiredName" ]; then
        # Change the host name now
        if hostname "$desiredName"; then
            myEcho "Running hostname: changed '$currentName' -> '$desiredName'"
            myLog "Running hostname: changed '$currentName' -> '$desiredName'"
        else
            myError "Running hostname: could not update running hostname to '$desiredName'"
        fi
    else
        myEcho "Running hostname: no changes requried for '$desiredName'"
    fi

    # Update /etc/hosts - if required. Will also replace -mgmt
    if grep -qw "$currentName" /etc/hosts && [ "$currentName" != "$desiredName" ]; then
        # update both "currentName" and "currentName-mgmt"
        if sed -i -E "s/([[:space:]])${currentName}(-mgmt)?([[:space:]]|\$)/\1${desiredName}\2\3/g" /etc/hosts; then
            myEcho "/etc/hosts updated: '$currentName' -> '$desiredName' (incl. -mgmt)"
            myLog "/etc/hosts updated: '$currentName' -> '$desiredName' (incl. -mgmt)"
        else
            myError "/etc/hosts could not be updated to '$desiredName'"
        fi
    else
        myEcho "/etc/hosts: no changes required for '$desiredName'"
    fi

    # Update /etc/hostname using hostnamectl instead of search and replace
    if [ "$hostnameFile" != "$desiredName" ]; then
        if hostnamectl hostname "$desiredName" --static; then
            myEcho "/etc/hostname: file changed: '$hostnameFile' -> '$desiredName'"
            myLog "/etc/hostname: file changed: '$hostnameFile' -> '$desiredName'"
        else
            myError "/etc/hostname: could not update hostname file to: '$desiredName'"
        fi
    else
        myEcho "/etc/hostname: no changes requried for '$desiredName'"
    fi
}

# Update the IP address. Takes argument of IP with no cidr
# Usage: -ip <ip>
# Updates the running, netplan and etc hosts file with the correct ips. 
function updateIP () {
    local desiredIP="$1"
    local intLan="$(ip route show default | awk '{print $5}')"
    local currentIP="$(ip -4 -o addr show dev "$intLan" | awk '{print $4}' | cut -d/ -f1)"

    # Confirm Current IP to requested IP
    if [ "$currentIP" = "$desiredIP" ]; then
        myEcho "IP: no change to ip required. IP already $currentIP"
        return 0
    fi

    # Netplan
    # No need to guard for currentIP desiredIP since the last guard already returns. 
    # This is basically the else path. 
    # checks for old ips and iff they exist you replace. 
    for f in /etc/netplan/*.yaml; do
        # Grep and check that its actually a new update
        # & [ "$networkIPcidr" != "$newIPcidr" ];
        if grep -q "$currentIP" "$f"; then
            if sed -i -e "s,${currentIP},${desiredIP},g" "$f"; then
                myEcho "IP: Replaced $currentIP with $desiredIP in $f"
                myLog "IP: Updated $f: $currentIP -> $desiredIP"
            else
                myError "IP: failed to replace IP in $f"
            fi
        fi
    done

    # ETC hosts replacement, mirroring netplan structure
    if grep -q "$currentIP" /etc/hosts; then
        if sed -i -e "s,${currentIP},${desiredIP},g" /etc/hosts; then
            myEcho "IP: Replaced $currentIP with $desiredIP in /etc/hosts"
            myLog "IP: Updated /etc/hosts: $currentIP -> $desiredIP"
        else
            myError "IP: failed to replace IP in /etc/hosts"
        fi
    fi

    # Apply the netplan. 
    if netplan apply; then
        myEcho "IP: Applied netplan: $desiredIP on $intLan"
    else
        myError "IP: Netplan Apply failed"
    fi
}

function hostEntry () {
    local newHost="$1"
    local newIP="$2"

    # First Case: Name present, IP correct

    if grep -qwE "^${newIP}[[:space:]].*\b${newHost}\b" /etc/hosts; then
        myEcho "HostEntry: no change, $newHost already set with $newIP"

    # Second Case: Name present, IP Incorrect

    elif grep -qw "$newHost" /etc/hosts; then
        # Starts with any form of ip eg 11.111.11.11 will even match more, + ads one or more of those values (11.)
        # () what parts to keep \b is word delim, capture group
        # \1 references the capture group. 
        if sed -i -E "s,^[0-9.]+([[:space:]].*\b${newHost}\b),${newIP}\1," /etc/hosts; then
            myEcho "HostEntry: updated $newHost -> $newIP"
            myLog "HostEntry: updated $newHost -> $newIP"
        else
            myError "HostEntry: Failed to updated /etc/hosts with $newHost $newIP"
        fi

    # Third Case: name missing, IP irrelevant
    else
        if echo "$newIP $newHost" >> /etc/hosts; then
            myEcho "HostEntry: added $newIP $newHost to /etc/hosts"
            myLog "HostEntry: /etc/hosts: added $newIP $newHost"
        else
            myError "HostEntry: /etc/hosts: failed to add $newIP $newHost"
        fi
    fi
}

# Handle command line args
while [ $# -gt 0 ]; do
    case "$1" in
        -v | -verbose | --verbose )
            verbose=1
            # myEcho "Verbose mode: on"
            ;;
        -n | -name )
            shift
            changeHostname "$1"
            ;;
        -ip )
            shift
            updateIP "$1"
            ;;
        -hostentry )
            shift
            newName="$1"
            shift
            hostEntry "$newName" "$1"
            ;;
    esac
    shift
done

# Return the amount of errors. 
exit $errors