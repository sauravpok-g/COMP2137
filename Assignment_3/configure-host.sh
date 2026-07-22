#!/bin/bash

# Script: Distributed System Configuration
# Author: Saurav Pokhrel (1863)
# Desc: 
# Modified: Jul 22 11:00


# TO DO:
# Command line args
#   -verbose
#   -name desiredName - 
#   -ip desiredIPAddress
#   -hostEntry desiredName desiredIP
# 
# Error "Handling", no output unless verbose EXCEPT for errors
# TERM, HUP, INT handling


#### Test that we're in the right machine first ####
#### REMOVE THIS OR REFINE LATER ####
host="$(hostname)"
dev="$(ip route | grep default | awk '{print $5'})"
ipAddr="$(ip -4 -o a show dev $dev | awk '{print $4}')"

echo "You've hit the test server: $host at $ipAddr"