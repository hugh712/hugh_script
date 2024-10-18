#!/bin/bash

echo -e "\nSetting up the testing environment..."

pwd='u'

# Disable auto upgrade
echo ${pwd} | sudo -S mv /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades.orig
echo -e "\033[1;32mModify 20auto-upgrades file: \033[0m"
cat << "EOF" | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
echo -e "\033[1;42;37mdone\033[0m"

# set current to be autologing
sudo ./bin/autologin.sh "$(whoami)"

# add super user
echo " $(whoami) ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stress-test

# Install packages
sudo apt install zenity util-linux stress -y
#sudo snap install fwts --beta

