#!/bin/bash

set -e
target_file=/etc/default/grub
parameter="drm.debug=0xffff log_buf_len=32m"

echo "Writing kernel parameter to $target_file"
sudo sed -i s/"GRUB_CMDLINE_LINUX=.*"/"GRUB_CMDLINE_LINUX=\"$parameter\""/g /etc/default/grub
echo "Running update-grub"
sudo update-grub
echo "Done, Please reboot the system"
