#!/bin/bash

IMG=$1
suffix=".iso"
pkg="zip p7zip-full"

# if there is no parameter, or the parameter is not a file
if [ -z "$IMG" ]; then
    read -p "Please enter ISO file path: " IMG
fi
if [ ! -f "$IMG" ]; then
    echo "Usage: $0 <path_to_iso_file>"
    exit 1
fi

if ! dpkg -l $pkg > /dev/null 2>&1; then
    sudo apt install $pkg -y
fi

if [ ! -f "$IMG" ]; then
    echo "Cannot find the image: $IMG"
    exit 1
fi

# absolute path of the ISO file
IMG=$(realpath "$IMG")
basename=$(basename "$IMG")
dirname=$(dirname "$IMG")

# output folder, zip file, and checksum file name
name_without_ext="${basename%.*}"
folder="$dirname/$name_without_ext"
zipfile="$dirname/$name_without_ext.zip"
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
echo "ZIP completed.The checksum of $zipfile is:"
cat "$checksumfile"
