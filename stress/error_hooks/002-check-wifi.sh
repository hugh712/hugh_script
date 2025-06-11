#!/bin/bash

me=$(basename "$0")
echo "checking $me"

interface=$(ip link show | awk -F: '$2 ~ /wlp/ {print $2; exit}' | tr -d ' ')

if [ -z "$interface" ]; then
    echo "Error: No Wi-Fi interface found"
    exit 1
fi

# check if the wifi is up

if ip link show "$interface" | grep -q "state UP"; then
    echo "Wi-Fi interface $interface is UP"
    exit 0
else
    echo "Error: Wi-Fi interface $interface found but not UP"
    exit 1
fi