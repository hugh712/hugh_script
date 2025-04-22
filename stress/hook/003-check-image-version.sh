#!/bin/bash

me=$(basename "$0")
echo "checking $me"

# load OS version information

if [ -f /etc/os-release ]; then
    image_version=$(grep "^VERSION=" /etc/os-release | cut -d= -f2 | tr -d '"')
    os_name=$(grep "^NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
elif [ -f /etc/issue ]; then
    image_version=$(head -n 1 /etc/issue | awk '{print $NF}')
    os_name=$(head -n 1 /etc/issue | awk '{$NF=""; print $0}')
else
    echo "Error: Cannot determine OS version"
    exit 1
fi

echo "Detected OS: $os_name"
echo "Detected Version: $image_version"

# except image version
expected_version="24.04"

# check if the image version matches the expected version
if [[ "$image_version" == *"$expected_version"* ]]; then
    echo "Image version check PASSED"
    exit 0
else
    echo "Error: Expected version $expected_version but found $image_version"
    exit 1
fi
