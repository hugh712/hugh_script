#!/bin/bash

target_device=$(cat ~/.stress_config/target_device)
device=$(ip a | grep "$target_device")
log_base=$(basename $0)
#log_file=${log_base%".sh"}".log"
err_file=${log_base%".sh"}".err"
#log=~/.stress_config/logs/"$log_name"
count_file=~/.stress_config/"$err_file"
current_error=~/.stress_config/this_error

if [ -z "$count_file" ]; then
	echo 0 > "$count_file"
fi
count_error=$(cat $count_file)

if [ -z "$device" ]; then
	count_error=$((count_error + 1))
  echo $count_error > $count_file
	echo "Can't not find device - $device" >> "$current_error"
	exit -1
fi
