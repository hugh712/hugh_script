#!/bin/bash

me=$(basename "$0")
echo "checking $me"

# detect MIPI interface (assuming it starts with wlp)
interface=$(ip link show | awk -F: '$2 ~ /wlp/ {print $2; exit}' | tr -d ' ')

if [ -z "$interface" ]; then
	echo "Error: No MIPI interface found"
	exit 1
fi

# check if the MIPI interface is present
if ip link show "$interface" &>/dev/null; then
	echo "MIPI interface $interface found"
else
	echo "Error: MIPI interface $interface not found"
	exit 1
fi