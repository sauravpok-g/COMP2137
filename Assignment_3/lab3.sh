#!/bin/bash
# This script runs the configure-host.sh script from the current directory to modify 2 servers and update the local /etc/hosts file

# Hold the string we will pass to configure-host.sh
verbose=""
errors=0

while [ $# -gt 0 ]; do
    case "$1" in
        -v | -verbose | --verbose )
            verbose="-verbose"
            shift
            ;;
    esac
    shift
done

# Error handling. 
function myError () {
    echo "LAB3: $*" >&2
    ((errors++))
}

# Deploy the script to the servers specified and run. 
# Usage: deploy <server> <args for configure-host.sh>
function deployScript () {
    host="$1"
    shift
    # Send the files over to server
    if ! scp configure-host.sh remoteadmin@"$host":/root; then
        myError "scp to $host failed -- skipping"
        return 1
    fi

    if ! ssh remoteadmin@"$host" -- /root/configure-host.sh $verbose "$@"; then
        myError "configure-host.sh on $host failed"
        return 1
    fi
}


# Deploy the configurations
deployScript server1-mgmt -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
deployScript server2-mgmt -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3

#scp configure-host.sh remoteadmin@server1-mgmt:/root
#ssh remoteadmin@server1-mgmt -- /root/configure-host.sh $verbose -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
#scp configure-host.sh remoteadmin@server2-mgmt:/root
#ssh remoteadmin@server2-mgmt -- /root/configure-host.sh $verbose -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3

if ! sudo ./configure-host.sh $verbose -hostentry loghost 192.168.16.3 ; then
    myError "local configure-host.sh failed for loghost"
fi

if ! sudo ./configure-host.sh $verbose -hostentry webhost 192.168.16.4 ; then
    myError "local configure-host.sh failed for webhost"
fi

if [ "$errors" -ne 0 ]; then
    echo "LAB3: returned with $errors failure(s)" >&2
    exit $errors
fi

exit 0