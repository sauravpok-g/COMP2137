#!/bin/bash


# Script: System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: Script to determine modifications requried, runs on target system to make modifications and reports on changes made


# Varaibles

# Setup Network Interface 


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

EOF

# Check squid Web proxy status

# Create Users accounts