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

# internal log for any errors
errors=0

# Custom Echo function. Takes n args. If verbose is on will echo, otherwise will not echo anything.
# TODO: Consider merging all the myFunctions to one with flags instead.
function myEcho () {
    [ "$verbose" -eq 1 ] && echo "$@"
}

function myLog () {
    logger -t $(basename "$0") -i -p user.warning
}

function myError () { 
    # Increment the error counter. Anything not 0 is an error. 
    errors+=1
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

# Return the amount of errors. 
return $errors