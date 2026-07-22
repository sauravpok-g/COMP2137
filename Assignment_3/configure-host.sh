#!/bin/bash

# Script: Distributed System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: 
# Modified: Jul 22 11:00


# TO DO:
# Command line args
#   -verbose (DONE)
#   -name desiredName 
#        this option will confirm the host has the desired name, updating it if necessary in both the /etc/hosts file and the /etc/hostname file
#        Verbose: Mention any changes made. 
#        if changes made: send to system log using logger describing the changes. 
#   -ip desiredIPAddress
#   -hostEntry desiredName desiredIP
# 
# Error "Handling", no output unless verbose EXCEPT for errors
# TERM, HUP, INT handling


#### Test that we're in the right machine first ####
#### REMOVE THIS OR REFINE LATER ####
currentHost="$(hostname)"
dev="$(ip route | grep default | awk '{print $5'})"
ipAddr="$(ip -4 -o a show dev $dev | awk '{print $4}')"

echo "You've hit the test server: $currentHost at $ipAddr"

# Track if we are in verbose
verbose=0

# Custom Echo function. Takes n args. If verbose is on will echo, otherwise will not echo anything.
function myEcho () {
    [ "$verbose" -eq 1 ] && echo "$@"
}

function myLog () {
    logger -t $(basename "$0") -i -p user.warning
}

function myError () { 

}

# Change Hostname in both /etc/hosts and /etc/hostname
# Only update if theres a change. 
# Takes one arg: DesiredName

# TO DO: Merge the running hostname and /etc/hostname since using hostnamectl updates both. 
function changeHostname () {
    local desiredName="$1"
    local currentName="$(hostname)"
    # Static used to only check /etc/hostname
    local hostnameFile="$(hostnamectl --static hostname)"

    # If running hostname doesnt match, change it
    if [ "$currentName" != "$desiredName" ]; then
        
        # Change the host name now
        if hostname "$desiredName"; then
            myEcho "Running hostname changed: '$currentName' -> '$desiredName'"
            myLog "Running hostname changed: '$currentName' -> '$desiredName'"
        else
            myError "could not update running hostname to '$desiredName'"
            return 1
        fi
    else
        myEcho "Hostname is already set to '$desiredName' - no changes made"
    fi
    # Update /etc/hosts

    # Update /etc/hostname using hostnamectl instead of search and replace
    if [ "$hostnameFile" != "$desiredName" ]; then
        if hostnamectl hostname "$desiredName" --static; then
            myEcho "Hostname file changed: '$currentName' -> '$desiredName'"
            myLog "Hostname file changed: '$currentName' -> '$desiredName'"
        else
            myError "could not update hostname file to: '$desiredName'"
            return 1
        fi

    fi

}

# Handle command line args
while [ $# -gt 0 ]; do
    case "$1" in
        -v | -verbose | --verbose )
            verbose=1
            myEcho "Verbose mode: on"
            ;;
        -n | -name )
            shift
            changeHostname $1
    esac
    shift
done