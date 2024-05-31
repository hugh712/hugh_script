#!/bin/bash

#Prerequisite
#1. Setup visuo for the user without typing password
#2. sudo apt install rtcwake zenity

if [ ! "$EUID" -ne 0 ] 
  then echo "Please do not run as root"
  exit
fi
user=$(whoami)
STRESS_COUNT=50

mkdir ~/.stress_config
echo "$STRESS_COUNT" >  ~/.stress_config/count_reboot
echo "$STRESS_COUNT" >  ~/.stress_config/count_reboot_total
echo 0 >  ~/.stress_config/count_error
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
count=$(cat $count_file)
count_total=$(cat $count_file_total)
output_message=""
#-1=detected
#0 =do no
#1 =shutown
service_status=0 # 0=do nothing, 
STRESS_BOOT_WAKEUP_DELAY=60

if [ ! "$count" -gt 0 ]; then
        #Show Report and exit

        output_message="Finished stress $count_total times"
        #zenity --info --text="$output_message" --title="Info"
        sudo systemctl disable shutdown_stress.service
        sudo systemctl stop shutdown_stress.service
        exit 0
else
        output_message="shutdown stress ($count/$count_total), will shutdown soon "
        service_status=1
fi

count=$((count - 1))
echo $count > $count_file

#zenity --info --text="$output_message" --title="Info"&
sleep 10

sudo rtcwake --mode off -s "$STRESS_BOOT_WAKEUP_DELAY"


EOF

sudo chown $user:$user /usr/bin/run_shutdown_stress
sudo chmod 700 /usr/bin/run_shutdown_stress
