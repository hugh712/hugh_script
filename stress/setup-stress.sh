#!/bin/bash

LOG_FILE="$HOME/setup-stress-full.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting setup..."

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

mkdir ~/.stress_config

echo "$STRESS_COUNT" > ~/.stress_config/count_reboot
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot_total
echo "reboot" > ~/.stress_config/method
echo 0 > ~/.stress_config/count_error
echo 0 > ~/.stress_config/err_stop
echo "$TARGET_DEVICE" > ~/.stress_config/target_device

# ensure the errormessages files exist
touch ~/.stress_config/error_log

# execute hooks
./run_hooks.sh
count_error=$(cat ~/.stress_config/count_error)
if [ "$count_error" -gt 0 ]; then
    echo -e "\033[0;31mError: Some hooks failed. Check ~/.stress_config/error_log for details.\033[0m"
    exit 1
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

sudo systemctl enable shutdown_stress.service
sudo tee /usr/bin/run_shutdown_stress > /dev/null <<'EOF'
#!/bin/bash

if [ -f /tmp/stop_stress_testing ]; then
    echo "[INFO] Stop signal detected. Disabling shutdown_stress.service"
    notify-send "Stress Test Stopped" "Manual stop signal received"
    sudo systemctl disable shutdown_stress.service
    sudo systemctl stop shutdown_stress.service
    exit 0
fi

count_file="$HOME/.stress_config/count_reboot"
count_file_total="$HOME/.stress_config/count_reboot_total"
count_file_error="$HOME/.stress_config/count_error"
count_file_log="$HOME/.stress_config/error_log"
err_stop_file="$HOME/.stress_config/err_stop"
count=$(cat "$count_file")
count_total=$(cat "$count_file_total")
count_error=$(cat "$count_file_error")
err_stop=$(cat "$err_stop_file")
do_stop=0
output_message=""
service_status=0
target_device=$(cat "$HOME/.stress_config/target_device")
STRESS_BOOT_WAKEUP_DELAY=60
method=$(cat "$HOME/.stress_config/method")

HOOK_SCRIPT="$HOME/hugh_script/stress/run_hooks.sh"
if [ -f "$HOOK_SCRIPT" ]; then
    bash "$HOOK_SCRIPT"
    if [ $? -ne 0 ]; then
        echo "Hooks failed, skipping this stress cycle." >> "$count_file_log"
        notify-send "Hook Error" "Hooks failed, skipping stress"
        exit 1
    fi
else
    echo "Warning: run_hooks.sh not found, skipping hook checks." >> "$count_file_log"
fi

device=$(ip -o link show | grep "$target_device")
err_m=$(sudo dmesg | grep "Bluetooth" | grep -i "fail")

if [ "$count" -le 0 ]; then
    if [[ -n "$err_m" || -z "$device" ]]; then
        count_error=$((count_error + 1))
        echo "$count_error" > "$count_file_error"
    fi
    output_message="Finished stress $count_total times, detected $count_error errors"
    notify-send "Info" "$output_message"
    sudo systemctl disable shutdown_stress.service
    sudo systemctl stop shutdown_stress.service
    exit 0
elif [[ -n "$err_m" || -z "$device" ]]; then
    service_status=-1
    count_error=$((count_error + 1))
    output_message="Err detected! $err_m"
    echo "$err_m" >> "$count_file_log"
    if [ -z "$device" ]; then
        echo "Cannot find $device" >> "$count_file_log"
        output_message="$output_message, Cannot find $device"
    fi
    echo "$count_error" > "$count_file_error"

    if [ "$err_stop" == 1 ]; then
        do_stop=1
    fi
else
    output_message="$method stress ($count/$count_total), will $method soon"
    service_status=1
fi

count=$((count - 1))
echo "$count" > "$count_file"

if [ "$service_status" == 1 ]; then
    notify-send "Info" "$output_message"
    sleep 10
elif [ "$service_status" == -1 ]; then
    notify-send "Warning" "$output_message"
fi

sleep 3

if [ "$do_stop" == 1 ]; then
    exit 0
fi

if [ "$method" == "reboot" ]; then
    sudo reboot
else
    sudo rtcwake --mode off -s "$STRESS_BOOT_WAKEUP_DELAY"
fi
EOF

sudo chmod 700 /usr/bin/run_shutdown_stress
sudo chown $user:$user /usr/bin/run_shutdown_stress

sudo tee /usr/bin/stop-stress > /dev/null <<'EOF'
#!/bin/bash

NORMAL_STOP_FILE="$HOME/.stress_config/count_reboot"
EMERGENCY_FLAG="/tmp/stop_stress_testing"
SERVICE_NAME="shutdown_stress.service"

function normal_stop() {
    echo "[STOP] Setting reboot count to 0"
    echo 0 > "$NORMAL_STOP_FILE"

    echo "[STOP] Stress test will stop after this cycle."
    notify-send "STOP" "Stress test will stop normally after this cycle."
}

function emergency_stop() {
    echo "[STOP NOW] Writing emergency stop flag: $EMERGENCY_FLAG"
    touch "$EMERGENCY_FLAG"

    echo "[STOP NOW] Disabling and stopping $SERVICE_NAME"
    sudo systemctl disable "$SERVICE_NAME"
    sudo systemctl stop "$SERVICE_NAME"

    echo "[STOP NOW] Stress test has been forcefully terminated."
    notify-send "STOP" "Stress test has been forcefully terminated!"
}

if [[ "$1" == "now" ]]; then
    emergency_stop
else
    normal_stop
fi
EOF

sudo chmod +x /usr/bin/stop-stress

echo "Setup completed successfully!"