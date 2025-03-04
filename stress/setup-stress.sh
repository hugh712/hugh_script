#!/bin/bash

if [ ! "$EUID" -ne 0 ]; then
  echo "Please do not run as root"
  exit
fi

# Set up environment
chmod +x ./bin/*
./bin/env-setup.sh
if [ $? -ne 0 ]; then
    echo -e '\033[0;31mError: ENV setup failed\033[0m'
    exit 1
fi

user=$(whoami)
STRESS_COUNT=50
TARGET_DEVICE=enx6018956e2b29

if [ ! -d ~/.stress_config ]; then
    mkdir ~/.stress_config
fi

echo "$STRESS_COUNT" > ~/.stress_config/count_reboot
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot_total
echo "reboot" > ~/.stress_config/method
echo 0 > ~/.stress_config/count_error
echo 0 > ~/.stress_config/err_stop
echo "$TARGET_DEVICE" > ~/.stress_config/target_device

# ensure error record
touch ~/.stress_config/error_log

# execute hooks
./run_hooks.sh

# check error
count_error=$(cat ~/.stress_config/count_error)
if [ "$count_error" -gt 0 ]; then
    echo "Warning: Some hooks failed. Check ~/.stress_config/error_log for details."
fi

# set systemd service
sudo bash -c "cat >/etc/systemd/system/shutdown_stress.service" <<"EOF"
[Unit]
Description=shutdown_stress service
After=plymouth-quit-wait.service
StartLimitIntervalSec=10

[Service]
Type=simple
Restart=on-failure
RestartSec=15
Environment=DISPLAY=:0
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
User=THE_USER
ExecStart=/usr/bin/bash /usr/bin/run_shutdown_stress

[Install]
WantedBy=multi-user.target
EOF

sudo sed -i s/"User=THE_USER"/"User=$user"/g /etc/systemd/system/shutdown_stress.service
sudo systemctl enable shutdown_stress.service

echo "Setup completed successfully!"
