#!/bin/bash
me=$(basename "$0")
echo "checking $me"

status=0

# check dmesg for mipi-related errors
mipi_keywords="mipi dsi"
dmesg_output=$(dmesg | grep -i "$mipi_keywords")

if echo "$dmesg_output" | grep -iE "fail|error|timeout"; then
  echo "[ERROR] MIPI related errors detected:"
  echo "$dmesg_output"
  status=1
else
  echo "No MIPI dmesg errors found"
fi

# check if MIPI interface is present
mipi_interface="mipi_video0"  # can be changed to /dev/videoX、ethX

if ip link show "$mipi_interface" &>/dev/null; then
  echo "MIPI interface $mipi_interface found"
else
  echo "[ERROR] MIPI interface $mipi_interface not found"
  status=1
fi

exit $status