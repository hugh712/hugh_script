#!/bin/bash

function printInfo()
{
    echo -e "======================== $1 ========================="
}

function is_intel()
{
	echo "$1" | grep "Intel"	
}

function is_nv()
{
	echo "$1" | grep "NVIDIA"	
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir temp

exec > gfx_info.log 2>&1

# lsb_release
printInfo "lsb_release"
lsb_release -a

# Kernel
printInfo "Kernel Info"
uname -a

# Image
printInfo "Image Info"
cat /var/lib/ubuntu_dist_channel

# GFX info
printInfo "lspci"
lspci -nnv

# collect whole dmesg
printInfo "Collect dmesg"
dmesg > dmesg.log

#collect whole journalctl
printInfo "Collect journalctl"
journalctl > journalctl.log

is_intel=$(lspci -nnv | grep VGA | grep "Intel")
is_nvidia=$(lspci -nnv | grep VGA | grep "NVDIA")
#if i915
if [ -n "$is_intel" ]; then
	printInfo "Detected Intel Gfx"
	./i915_collect.sh	
fi
#if nvidia
if [ -n "$is_nvidia" ]; then
	printInfo "Detected Nvidia Gfx"
	./nv_collect.sh
fi

mv dmesg.log temp
mv journalctl.log temp
mv gfx_info.log temp 
mv i915_info.log temp
mv nv_info.log temp

tar Jcf gfxlog.txz temp/*
