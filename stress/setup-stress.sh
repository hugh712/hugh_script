#!/bin/bash

if [ ! "$EUID" -ne 0 ] 
  then echo "Please do not run as root"
  exit
fi

# Set up environment
chmod +x ./bin/*
./bin/env-setup.sh
if [ $? -ne 0 ]; then
        echo '\033[0;31mError: ENV setup failed\033[0m'
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
echo "reboot" >  ~/.stress_config/method
echo 0 > ~/.stress_config/count_error
echo 0 > ~/.stress_config/err_stop
echo "$TARGET_DEVICE" > ~/.stress_config/target_device

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

#setup runtime script
sudo bash -c "cat >/usr/bin/run_shutdown_stress" <<"EOF"
#!/bin/bash
count_file=~/.stress_config/count_reboot
count_file_total=~/.stress_config/count_reboot_total
count_file_error=~/.stress_config/count_error
count_file_log=~/.stress_config/error_log
err_stop_file=~/.stress_config/err_stop
count=$(cat $count_file)
count_total=$(cat $count_file_total)
count_error=$(cat $count_file_error)
err_stop=$(cat $err_stop_file)
do_stop=0
output_message=""
#-1=detected
#0 =do no
#1 =shutown
service_status=0 # 0=do nothing, 
target_device=$(cat ~/.stress_config/target_device)
STRESS_BOOT_WAKEUP_DELAY=60

device=$(ip a | grep "$target_device")
err_m=$(sudo dmesg | grep "iwlwifi" | grep -i "failed")
method=$(cat ~/.stress_config/method)

if [ ! "$count" -gt 0 ]; then
        #Show Report and exit

        if [[ -n "$err_m" || -z "$device" ]]; then
                count_error=$((count_error + 1))
                echo $count_error > $count_file_error
        fi
        output_message="Finished stress $count_total times, detected $count_error times"
	notify-send "Info" "$output_message"
        sudo systemctl disable shutdown_stress.service
        sudo systemctl stop shutdown_stress.service
        exit 0
elif [[ -n "$err_m" || -z "$device" ]]; then
        service_status=-1
        count_error=$((count_error + 1))
	output_message="Err detected! $err_m \n "
	echo "$err_m" >> "$count_file_log"
	if [ -z "$device" ]; then
		echo "Can not find $device" >> "$count_file_log"
		output_message="$output_message, \nCan not find $device "
	fi
        echo $count_error > $count_file_error

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

if [ "$do_stop" == 1 ]; then
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

sudo chown $user:$user /usr/bin/run_shutdown_stress
sudo chmod 700 /usr/bin/run_shutdown_stress
