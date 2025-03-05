#!/bin/bash

IMG=$1
suffix=".iso"
pkg="zip p7zip-full"

if ! dpkg -l $pkg > /dev/null 2>&1; then
    sudo apt install $pkg -y
fi

if [ ! -f "$IMG" ]; then
    echo "Cannot find the image: $IMG"
    exit 1
fi

# absolute path of the ISO file
IMG=$(realpath "$IMG")

#  ISO file name without the suffix
basename=$(basename "$IMG" "$suffix")
dirname=$(dirname "$IMG")

# output folder, zip file, and checksum file name
folder="$dirname/$basename"
zipfile="$dirname/$basename.zip"
checksumfile="$zipfile.sha256sum"

rm -rf "$folder"

7z x "$IMG" -o"$folder"

# enter the folder and zip all files
cd "$folder" || exit
zip -r "$zipfile" .
cd "$dirname" || exit

# gen SHA256 checksum
sha256sum "$zipfile" > "$checksumfile"

echo ""
echo "The checksum of $zipfile is:"
cat "$checksumfile"
