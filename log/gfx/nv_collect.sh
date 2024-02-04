#!/bin/bash

function printInfo()
{
    echo -e "======================== $1 ========================="
}

if [ "\$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
exec > nv_info.log 2>&1

# Generate nvidia bug report
printInfo "nvidia-bug-report"
nvidia-bug-report.sh

# Related nvidia packages
printInfo "Nvidia packages"
dpkg -l | grep nvidia

# prime-select
printInfo "prime-select"
prime-select query

# collect nvidia_smi if Nvidia
printInfo "nvidia-smi"
nvidia-smi

mv nvidia-bug-report.log.gz temp
