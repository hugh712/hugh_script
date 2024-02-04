#!/bin/bash

mkdir mnt
for path in /sys/class/block/*; do
	dev=$(basename "$path")
	if [[ "$dev" == *"loop"* ]]; then
		continue
	fi
	#PARTLABEL="ISO9660"
	#PARTLABEL="OS"
	id=$(blkid /dev/"$dev")
	if [[ "$id" == *"PARTLABEL=\"ISO9660\" "* || "$id" == *"PARTLABEL=\"OS\" "*  ]]; then
		#mount
		mount /dev/"$dev" mnt
		#run md5sum to temp
		cd mnt/
		md5sum -c md5sum.txt > ../md5_"$dev".log
		
		#umount
		cd ..
		umount mnt
	fi	

done

rmdir mnt
