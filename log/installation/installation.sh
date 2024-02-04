#!/bin/bash

function printInfo()
{
    echo -e "======================== $1 ========================="
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir temp

exec > installation_info.log 2>&1

# lsb_release
printInfo "lsb_release"
lsb_release -a

# Kernel
printInfo "Kernel Info"
uname -a

# Image
printInfo "Image Info"
cat /var/lib/ubuntu_dist_channel

# disk space usage
printInfo "Disk Space Usage"
df -h
(cd / ; ls / | xargs du -hs)


# lsblk
printInfo "lsblk"
lsblk

# lspci info
printInfo "lspci"
lspci -nnv

# blkid
printInfo "blkid"
blkid

# Recovery md5sum
printInfo "Check md5sum for systems"
./check_md5.sh

# collect whole dmesg
printInfo "Collect dmesg"
dmesg > dmesg.log

#collect whole journalctl
printInfo "Collect journalctl"
journalctl > journalctl.log

mv dmesg.log temp
mv journalctl.log temp
mv installation_info.log temp 
mv md5_*.log temp
cp -rf /var/log/installer temp
dpkg -l > temp/dpkg.log

tar Jcf installation.txz temp/*
