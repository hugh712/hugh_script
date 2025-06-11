#!/bin/bash

LOG_FILE="$HOME/setup-stress-full.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting setup..."

if [ "$EUID" -eq 0 ]; then
  echo "Please do not run as root"
  exit 1
fi

chmod +x ./bin/*
./bin/env-setup.sh
if [ $? -ne 0 ]; then
    echo -e '\033[0;31mError: ENV setup failed\033[0m'
    exit 1
fi

user=$(whoami)
STRESS_COUNT=50
TARGET_DEVICE=enx6018956e2b29
STOP_ON_ERROR=1

mkdir -p ~/.stress_config
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot
echo "$STRESS_COUNT" > ~/.stress_config/count_reboot_total
echo "reboot" > ~/.stress_config/method
echo "$STOP_ON_ERROR" > ~/.stress_config/err_stop
echo 0 > ~/.stress_config/count_error
echo "$TARGET_DEVICE" > ~/.stress_config/target_device
touch ~/.stress_config/error_log

# Run pre-check hooks before setting service
echo "[INFO] Running pre-check error_hooks"
hook_failed=0

for hook in "$HOME/hugh_script/stress/error_hooks/"*.sh; do
    echo "[HOOK] Executing $hook"
    bash "$hook"
    result=$?
    if [ $result -ne 0 ]; then
        echo "[HOOK FAIL] $hook failed" | tee -a "$HOME/.stress_config/error_log"
        hook_failed=1
    fi
done

if [ "$hook_failed" -ne 0 ]; then
    echo -e "\033[0;31m[ERROR] One or more hooks failed. Setup aborted.\033[0m"
    exit 1
fi

# Define shutdown_stress systemd service
sudo tee /etc/systemd/system/shutdown_stress.service > /dev/null <<EOF
[Unit]
Description=shutdown_stress service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10
User=$user
ExecStart=/usr/bin/run_shutdown_stress

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable shutdown_stress.service

# Define /usr/bin/run_shutdown_stress
sudo tee /usr/bin/run_shutdown_stress > /dev/null <<'EOF'
#!/bin/bash

count_file="$HOME/.stress_config/count_reboot"
count_file_total="$HOME/.stress_config/count_reboot_total"
count_file_error="$HOME/.stress_config/count_error"
count_file_log="$HOME/.stress_config/error_log"
err_stop=$(cat "$HOME/.stress_config/err_stop")
target_device=$(cat "$HOME/.stress_config/target_device")
method=$(cat "$HOME/.stress_config/method")
STRESS_BOOT_WAKEUP_DELAY=60

count=$(cat "$count_file")
count_total=$(cat "$count_file_total")
count_error=$(cat "$count_file_error")
do_stop=0
output_message=""
service_status=0

# Run hooks to validate after stress
hook_failed=0
for hook in "$HOME/hugh_script/stress/error_hooks/"*.sh; do
    echo "[HOOK] Executing $hook"
    bash "$hook"
    result=$?
    if [ $result -ne 0 ]; then
        echo "[HOOK FAIL] $hook" >> "$count_file_log"
        hook_failed=1
    fi
done

if [ "$hook_failed" -ne 0 ]; then
    echo "[FAIL] Detected failure in hooks"
    count_error=$((count_error + 1))
    echo "$count_error" > "$count_file_error"

    if [ "$err_stop" == "1" ]; then
        echo "[STOP] err_stop=1, stopping stress service"
        notify-send "HOOK FAILED" "Stopping test due to hook failure"
        sudo systemctl disable shutdown_stress.service
        sudo systemctl stop shutdown_stress.service
        exit 1
    fi
fi

# Continue stress logic
if [ "$count" -le 0 ]; then
    notify-send "Stress Test Done" "Total: $count_total, Errors: $count_error"
    sudo systemctl disable shutdown_stress.service
    sudo systemctl stop shutdown_stress.service
    exit 0
fi

output_message="$method stress ($count/$count_total)"
echo "[INFO] $output_message"
notify-send "Info" "$output_message"

count=$((count - 1))
echo "$count" > "$count_file"
sleep 3

# Action
if [ "$method" == "reboot" ]; then
    sudo reboot
else
    sudo rtcwake --mode off -s "$STRESS_BOOT_WAKEUP_DELAY"
fi
EOF

sudo chmod 700 /usr/bin/run_shutdown_stress
sudo chown "$user:$user" /usr/bin/run_shutdown_stress

# Provide stop-stress command
sudo tee /usr/bin/stop-stress > /dev/null <<'EOF'
#!/bin/bash

NORMAL_STOP_FILE="$HOME/.stress_config/count_reboot"
EMERGENCY_FLAG="/tmp/stop_stress_testing"
SERVICE_NAME="shutdown_stress.service"

function normal_stop() {
    echo "[STOP] Setting reboot count to 0"
    echo 0 > "$NORMAL_STOP_FILE"
    notify-send "STOP" "Stress test will stop after this cycle."
}

function emergency_stop() {
    echo "[STOP NOW] Writing emergency stop flag: $EMERGENCY_FLAG"
    touch "$EMERGENCY_FLAG"
    sudo systemctl disable "$SERVICE_NAME"
    sudo systemctl stop "$SERVICE_NAME"
    notify-send "STOP" "Stress test forcefully terminated!"
}

if [[ "$1" == "now" ]]; then
    emergency_stop
else
    normal_stop
fi
EOF

sudo chmod +x /usr/bin/stop-stress