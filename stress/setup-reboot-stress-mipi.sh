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

mkdir -p ~/.stress_config
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot_total
echo 0 > ~/.stress_config/count_error
echo "reboot" > ~/.stress_config/method
echo "$user" > ~/.stress_config/owner
echo 1 > ~/.stress_config/err_stop

# Run error_hooks before setting up the service
echo "[INFO] Running error_hooks for MIPI stress preparation..."
hook_failed=0
for hook in "$HOME/hugh_script/stress/error_hooks/"*.sh; do
  echo "[HOOK] Executing $hook"
  bash "$hook"
  result=$?
  if [ $result -ne 0 ]; then
    echo "[ERROR] Hook $hook failed"
    hook_failed=1
  fi
done

if [ "$hook_failed" -ne 0 ]; then
  echo -e "\033[0;31m[ERROR] One or more hooks failed. Aborting setup.\033[0m"
  exit 1
fi

# setup systemd service
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
User=THE_USER
ExecStart=/usr/bin/bash /usr/bin/run_shutdown_stress

[Install]
WantedBy=multi-user.target
EOF

# replace placeholder
sudo sed -i s/"User=THE_USER"/"User=$user"/g /etc/systemd/system/shutdown_stress.service
sudo systemctl enable shutdown_stress.service

# setup runtime script
sudo bash -c "cat >/usr/bin/run_shutdown_stress" <<"EOF"
#!/bin/bash
count_file=~/.stress_config/count_reboot
count_file_total=~/.stress_config/count_reboot_total
count_file_error=~/.stress_config/count_error
count_file_log=~/.stress_config/error_log
count=$(cat $count_file)
count_total=$(cat $count_file_total)
count_error=$(cat $count_file_error)
THE_ERR="switch camera to host failed"
output_message=""
service_status=0
STRESS_BOOT_WAKEUP_DELAY=60

err_m=$(sudo dmesg | grep "$THE_ERR")
err_vsc=$(sudo dmesg | grep "vsc" | grep "failed")

if [ ! "$count" -gt 0 ]; then
  if [ -n "$err_m" ]; then
    count_error=$((count_error + 1))
  fi
  output_message="Finished stress $count_total times"
  zenity --info --text="$output_message" --title="Info"
  sudo systemctl disable shutdown_stress.service
  sudo systemctl stop shutdown_stress.service
  exit 0
elif [[ -n "$err_m" || -n "$err_vsc" ]]; then
  output_message="Err detected!"
  service_status=-1
  count_error=$((count_error + 1))
  echo "$err_m" >> "$count_file_log"
  echo "$err_vsc" >> "$count_file_log"
  echo $count_error > $count_file_error
else
  output_message="shutdown stress ($count/$count_total), will shutdown soon"
  service_status=1
fi

count=$((count - 1))
echo $count > $count_file

zenity --info --text="$output_message" --title="Info"&
sleep 10
sudo reboot
EOF

sudo chown $user:$user /usr/bin/run_shutdown_stress
sudo chmod 700 /usr/bin/run_shutdown_stress

echo "[INFO] setup-reboot-stress-mipi.sh completed"