#!/bin/bash

me=$(basename "$0")
echo "checking $me"

# check wire interface
# find the first ethernet interface (eno* or eth*)
interface=$(ip link show | awk -F: '$2 ~ /eno|eth/ {print $2; exit}' | tr -d ' ')
if [ -z "$interface" ]; then
    echo "Skipping $me: No ethernet interface found"
    exit 0  # Not an error, just skip
fi

# check if the interface is present
if ip link show "$interface" &>/dev/null; then
    echo "Interface $interface found"
else
    echo "Error: Interface $interface not found"
    exit 1
fi

#run the command to check if the interface is present
err=$(ip a | grep "$interface")