#!/bin/bash

if [ ! "$EUID" -ne 0 ] 
  then echo "Please do not run as root"
  exit
fi

# Set up environment
chmod +x ./bin/*
./bin/env-setup.sh
return_code=$?
if [  "$return_code" -ne 0 ]; then
    printf '\033[0;31mError: ENV setup failed\033[0m'
    exit 1
fi

user=$(whoami)
STRESS_COUNT=50
TARGET_DEVICE=enx6018956e2b29

if [ ! -d ~/.stress_config ]; then
    mkdir ~/.stress_config
fi

echo "$STRESS_COUNT" >  ~/.stress_config/count_reboot
echo "$STRESS_COUNT" >  ~/.stress_config/count_reboot_total
echo "$TARGET_DEVICE" > ~/.stress_config/target_device
echo "reboot" >  ~/.stress_config/method
echo "" > ~/.stress_config/log
echo 0 > ~/.stress_config/err_stop
rm ~/.stress_config/*.err

#setup systemd service 
sudo bash -c "cat >/etc/systemd/system/shutdown_stress.service" <<"EOF"
[Unit]
Description=shutdown_stress service
#After=network.target
After=plymouth-quit-wait.service
StartLimitIntervalSec=10

[Service]
Type=simple
Restart=on-failure
#After=network-online.target
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

sudo mkdir -p /usr/local/stress_hook/
sudo cp hooks/* /usr/local/stress_hook/
sudo chmod 744 /usr/local/stress_hook/*.sh

#setup runtime script
sudo bash -c "cat >/usr/bin/run_shutdown_stress" <<"EOF"
#!/bin/bash

#File Pathes
count_file_total=~/.stress_config/count_reboot_total
err_stop_file=~/.stress_config/err_stop
current_error=~/.stress_config/this_error
stress_hooks=/usr/local/stress_hook/
count_file=~/.stress_config/count_reboot
log_file=~/.stress_config/logs

# Variables
method=$(cat ~/.stress_config/method)
count=$(cat $count_file)
count_total=$(cat $count_file_total)
err_stop=$(cat $err_stop_file)
do_stop=0
output_message=""
#-1=detected
#0 =do no
#1 =shutown
service_status=0 # 0=do nothing, 
STRESS_BOOT_WAKEUP_DELAY=60

# Initialize
echo "" > $current_error

logger "========stress-cycle-$count/$count_total========="

for file in "$stress_hooks"*.sh; do
    bash $file
    
    if [[ "$?" != 0 && "$err_stop" == 1 ]]; then
        do_stop=1
    fi
done

errors=$(cat "$current_error")

if [ ! "$count" -gt 0 ]; then
    #Show Report and exit

    output_message="Finished stress $count_total times"
    
    err_count=$(ls ~/.stress_config/*.err)
    if [ -n "$err_count" ]; then
        output_message="$output_message ; Error Found"
        output_message="$output_message ; Please use 'cat ~/.stress_config/*.err to check'"
        output_message="$output_message ; and use 'cat ~/.stress_config/log to check'"
    else
        output_message="$output_message ; No Error Found"
    fi

    notify-send "Info" "$output_message"
    sudo systemctl disable shutdown_stress.service
    sudo systemctl stop shutdown_stress.service
    exit 0
elif [ -n "$errors" ]; then
    # Got errors
    
    service_status=-1
    output_message="Err detected! $errors \n "
    echo "" >> "$log_file"
    echo "$======$count======" >> "$log_file"
    echo "$errors" >> "$log_file"

    if [ "$err_stop" == 1 ]; then
        do_stop=1
    fi
else
    output_message="$method stress ($count/$count_total), will $method soon "
    service_status=1
fi

count=$((count - 1))
echo $count > $count_file

if [ "$service_status" == 1 ]; then
    notify-send "Info" "$output_message"
    sleep 10
elif [ "$service_status" == -1 ]; then
    notify-send "Warning" "$output_message"
fi

sleep 3

if [[ -n "$errors" && "$do_stop" == 1 ]]; then
    exit 0
fi


if [ "$method" == "reboot" ]; then
    sudo reboot
else
    sudo rtcwake --mode off -s "$STRESS_BOOT_WAKEUP_DELAY"
fi


EOF

sudo cp bin/stop-stress /usr/bin/
sudo cp bin/start-stress /usr/bin/
sudo chmod 755 /usr/bin/stop-stress
sudo chmod 755 /usr/bin/start-stress

sudo chown "$user":"$user" /usr/bin/run_shutdown_stress
sudo chmod 700 /usr/bin/run_shutdown_stress
