#!/bin/bash

IMG=$1
suffix=".iso"
pkg="zip p7zip-full"

if ! dpkg -l $pkg> /dev/null 2>&1; then
      sudo apt install $pkg -y;
fi

if [ ! -f "$IMG" ]; then
	echo "Can not find the image $IMG"
	exit 1
fi

folder=${IMG%"$suffix"};

rm -rf "$folder"

7z x "$IMG" -o"$folder"

cd "$folder" || exit

zip -r ../"$folder".zip * .*
