#!/bin/bash

# Script: setup-network-reboot-stress.sh
# Usage: sudo ./setup-network-reboot-stress.sh <cycle>
# Log: /var/log/network_reboot_stress.log

MAX_COUNT=$1
STATE_FILE="/var/lib/network_reboot_state"
LOG_FILE="/var/log/network_reboot_stress.log"
CHECK_NETWORK_SCRIPT="/usr/local/bin/check_network.sh"
CONTROL_SCRIPT="/usr/local/bin/network_reboot_cycle.sh"
SERVICE_FILE="/etc/systemd/system/network-reboot.service"

if [[ -z "$MAX_COUNT" || "$MAX_COUNT" -le 0 ]]; then
  echo "Please enter the reboot cycle, e.g., sudo $0 5"
  exit 1
fi

echo "Initialize network reboot test for $MAX_COUNT cycles"

# build state file
echo "0/$MAX_COUNT" > "$STATE_FILE"

# build network checking script
cat << 'EOF' > "$CHECK_NETWORK_SCRIPT"
#!/bin/bash
LOG_FILE="/var/log/network_reboot_stress.log"
WAIT_TIME=60
CONNECTED=0

echo "[`date`] 🌐 Resume from reboot, start checking network" >> "$LOG_FILE"

for ((i=0; i<$WAIT_TIME; i++)); do
  NSLOOKUP_OUTPUT=$(nslookup google.com 2>&1)

  if ! echo "$NSLOOKUP_OUTPUT" | grep -q -E "timed out|can't find|no servers"; then
    echo "[`date`] ✅ SUCCESS: network connect (nslookup) to google.com" >> "$LOG_FILE"
    CONNECTED=1
    break
  fi

  sleep 1
done

if [[ $CONNECTED -eq 0 ]]; then
  echo "[`date`] ❌ FAIL: network CANNOT connect (nslookup) to google.com" >> "$LOG_FILE"
fi
EOF

chmod +x "$CHECK_NETWORK_SCRIPT"

# build main control script
cat << EOF > "$CONTROL_SCRIPT"
#!/bin/bash
STATE_FILE="/var/lib/network_reboot_state"
LOG_FILE="/var/log/network_reboot_stress.log"
CHECK_NETWORK_SCRIPT="/usr/local/bin/check_network.sh"

# execute network checking
bash "\$CHECK_NETWORK_SCRIPT"

# read the state
if [[ ! -f "\$STATE_FILE" ]]; then
  echo "0/$MAX_COUNT" > "\$STATE_FILE"
fi

CURRENT=\$(cut -d '/' -f 1 "\$STATE_FILE")
MAX=\$(cut -d '/' -f 2 "\$STATE_FILE")

if [[ "\$CURRENT" -lt "\$MAX" ]]; then
  NEW_COUNT=\$((CURRENT + 1))
  echo "\$NEW_COUNT/\$MAX" > "\$STATE_FILE"
  echo "[`date`] 🔁 \$NEW_COUNT cycles rebooting..." >> "\$LOG_FILE"
  sleep 3
  reboot
else
  echo "[`date`] ✅ Finish \$MAX cycles network reboot test" >> "\$LOG_FILE"
fi
EOF

chmod +x "$CONTROL_SCRIPT"

# build systemd service
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Network Reboot Cycle Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$CONTROL_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

# enable service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable network-reboot.service

echo "✅ Finish installation, please reboot to start the testing."
