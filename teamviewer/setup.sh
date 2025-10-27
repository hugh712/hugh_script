#!/bin/bash

EULA_COUNT=20
# Set to teamview-host for headless
headless="-host"

function ping_google()
{
    ping www.google.com -c 5 > /dev/null
    echo $?
}

function printError()
{
    echo -e "🚫 \033[31m[Error] $1 \033[0m"
}

function printInfo()
{
    echo -e "\033[32m[Info] $1 \033[0m"
}

if [ "$EUID" -ne 0 ]; then 
    printError "Please run as root"
    exit
fi

# Parsing arguments
while [ -n "$1" ]; do
    case "$1" in
        -p )
            printInfo "Only Generate Password"
            makepasswd --chars=16
            exit 0
            ;;  
        --head )
            printInfo "Set to teamviewer"
            headless=""
            ;;
        * ) 
            printError "ERROR: unknown option $1"
            usage
            ;;  
    esac                                                                                                                                                      
    shift
done
printInfo "🌐 Checking Internet Connection"
if [ "$(ping_google)" != "0" ]; then
    printError "Please check your internet status"
    exit 1
fi

printInfo "🔧 TeamViewer Host auto setup"

# Check Arch
arc="amd64"
arc_tmp=$(arch)
if [ "$arc_tmp" == "aarch64" ]; then
    printInfo "💻 Set Arch to arm64"
    arc="arm64"
elif [ "$arc_tmp" == "x86_64" ]; then
    printInfo "💻 Set Arch to amd64"
elif [ "$arc_tmp" == "i386" ]; then
    printInfo "💻 Set Arch to i386"
    arc="i386"
elif [ "$arc_tmp" == "armv7l" ]; then
    printInfo "💻 Set Arch to arm32"
    arc="armhf"
else
    printError "Archticture $arc_tmp not supported"
    exit 1 
fi
set -e
if ! dpkg -s teamviewer"$headless" >/dev/null 2>&1; then
  printInfo "📦 No detect teamviewer$headless，Start to install..."
  sudo apt update -y
  sudo apt install -y wget gdebi-core makepasswd
  header="https://download.teamviewer.com/download/linux/teamviewer"
  suffix=".deb"
  wget -O /tmp/teamviewer.deb "$header""$headless"_"$arc""$suffix"
  sudo gdebi -n /tmp/teamviewer.deb || sudo apt -f install -y
else
  printInfo "✅ Teamviewer$headless Installed"
fi
set +e

# Enable daemon
printInfo "🚀 Enable TeamViewer Service..."
sudo systemctl enable teamviewerd.service
sudo systemctl start teamviewerd.service

eula=$(sudo teamviewer license show | grep accepted)

if [ -z "$eula" ]; then

    printInfo "📄 Auto Accepting Eula for Teamview"


    printInfo "✍️ You have $EULA_COUNT secs to cancel auto Accepting..."
    printInfo "✍️ Please Press Ctrl + C to Cancel this process..."
    sudo teamviewer license show
    for ((chrono="$EULA_COUNT"; chrono > 0; chrono--)); do 
        echo $chrono 
        sleep 1
    done

    sudo teamviewer license accept
fi

printInfo "📄 EULA Auto Accepted"

# Assign PW and Print info
printInfo "🔒 Setting Password for teamview"
ThePass=$(makepasswd --chars=16)
sudo teamviewer passwd "$ThePass"


printInfo "😈 Restarting Daemon"
sudo systemctl restart teamviewerd.service
sleep 5

printInfo "📄 Please make sure below service is running"
sudo teamviewer info | grep "Active:"

printInfo "👷 Please provide below infomation to the Engineer(s)"
sudo teamviewer info | grep "TeamViewer ID"
echo " The Password:  $ThePass"

printInfo "🔒 Or you can reset passowrd via below command"
printInfo "--> sudo teamviewer passwd 'YourPassWord'"
printInfo "✅ Setting Done!!"
