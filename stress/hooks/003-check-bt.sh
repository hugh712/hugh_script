#!/bin/bash

target_device=$(cat ~/.stress_config/target_device)
device=$(ip a | grep "$target_device")
log_base=$(basename $0)
err_file=${log_base%".sh"}".err"
count_file=~/.stress_config/"$err_file"
current_error=~/.stress_config/this_error

if [ -z "$count_file" ]; then
	echo 0 > "$count_file"
fi
count_error=$(cat $count_file)

err_m=$(sudo dmesg | grep "Bluetooth" | grep -i "fail")

if [ -n "$err_m" ]; then
	count_error=$((count_error + 1))
  echo $count_error > $count_file
	echo "Detect Bluetooth error message - $err_m" >> "$current_error"
	exit -1
fi
