#!/usr/bin/env bash
set -e

# ------------------------------------------------------------
# Print all stderr messages in red
# ------------------------------------------------------------
exec 2> >(while IFS= read -r line; do
    printf '\033[31mERROR: %s\033[0m\n' "$line" >&2
done)

SUPPORT_USER="hugh"
SERVICE_NAME="ngrok-ssh"

RUN_USER="$(id -un)"
RUN_HOME="$HOME"

usage() {
    echo "Usage:"
    echo "  $0 [-r ngrok_url] [-l launchpad_id] <token>"
    echo
    echo "Examples:"
    echo "  $0 TOKEN"
    echo "  $0 -l hugh712 TOKEN"
    echo "  $0 -r tcp://1.tcp.ngrok.io:23456 TOKEN"
    echo "  $0 -l hugh712 -r tcp://1.tcp.ngrok.io:23456 TOKEN"
    echo "  $0 TOKEN -r tcp://1.tcp.ngrok.io:23456 -l hugh712"
}

ngrok_url=""
launchpad_id=""
token=""

# ------------------------------------------------------------
# Parse arguments
# Parameter order does not matter
# ------------------------------------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r)
            if [ -z "${2:-}" ]; then
                echo "Option -r requires an ngrok URL." >&2
                usage
                exit 1
            fi

            ngrok_url="$2"
            shift 2
            ;;

        -l)
            if [ -z "${2:-}" ]; then
                echo "Option -l requires a Launchpad ID." >&2
                usage
                exit 1
            fi

            launchpad_id="$2"
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;

        *)
            if [ -z "$token" ]; then
                token="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

# ------------------------------------------------------------
# Do not allow root execution
# ------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "This script must NOT be run as root." >&2
    exit 1
fi

# ------------------------------------------------------------
# Token is mandatory
# ------------------------------------------------------------
if [ -z "$token" ]; then
    echo "Missing required ngrok token." >&2
    usage
    exit 1
fi

echo
echo "=========================================="
echo " Remote Support Setup"
echo "=========================================="
echo

# ------------------------------------------------------------
# Update package list
# ------------------------------------------------------------
echo "[1/9] Updating apt package list..."
sudo apt update

# ------------------------------------------------------------
# Install required packages
# ------------------------------------------------------------
echo
echo "[2/9] Installing SSH, tmux, curl and openssl..."
sudo apt install -y openssh-server tmux curl openssl

# ------------------------------------------------------------
# Install ngrok only if missing
# ------------------------------------------------------------
echo
echo "[3/9] Checking ngrok..."

if command -v ngrok >/dev/null 2>&1; then
    echo "ngrok is already installed."
    echo "Skipping ngrok installation."
else
    echo "Installing ngrok..."
    sudo snap install ngrok
fi

NGROK_BIN="$(command -v ngrok)"

if [ -z "$NGROK_BIN" ]; then
    echo "ngrok command not found after installation." >&2
    exit 1
fi

echo "ngrok binary:"
echo "  $NGROK_BIN"

# ------------------------------------------------------------
# Enable SSH server
# ------------------------------------------------------------
echo
echo "[4/9] Enabling SSH service..."

sudo systemctl enable --now ssh

if systemctl is-active --quiet ssh; then
    echo "SSH service is running."
else
    echo "SSH service failed to start." >&2
    exit 1
fi

# ------------------------------------------------------------
# Create support user
# ------------------------------------------------------------
echo
echo "[5/9] Preparing support user: $SUPPORT_USER"

if id "$SUPPORT_USER" >/dev/null 2>&1; then
    echo "User '$SUPPORT_USER' already exists."
    echo "Skipping user creation."
else
    sudo useradd \
        --create-home \
        --shell /bin/bash \
        "$SUPPORT_USER"

    echo "User '$SUPPORT_USER' created."
fi

sudo usermod -aG sudo "$SUPPORT_USER"

# ------------------------------------------------------------
# Configure NOPASSWD sudo
# ------------------------------------------------------------
echo
echo "[6/9] Enabling passwordless sudo for '$SUPPORT_USER'..."

sudo tee "/etc/sudoers.d/$SUPPORT_USER" >/dev/null <<EOF
$SUPPORT_USER ALL=(ALL) NOPASSWD:ALL
EOF

sudo chmod 440 "/etc/sudoers.d/$SUPPORT_USER"

if sudo visudo -cf "/etc/sudoers.d/$SUPPORT_USER" >/dev/null; then
    echo "sudoers configuration is valid."
else
    echo "Invalid sudoers configuration." >&2
    sudo rm -f "/etc/sudoers.d/$SUPPORT_USER"
    exit 1
fi

# ------------------------------------------------------------
# Import Launchpad SSH keys
# ------------------------------------------------------------
echo

if [ -n "$launchpad_id" ]; then

    echo "[7/9] Importing SSH public keys from Launchpad..."
    echo "Launchpad account:"
    echo "  $launchpad_id"

    launchpad_keys_url="https://launchpad.net/~${launchpad_id}/+sshkeys"

    keys="$(curl -fsSL "$launchpad_keys_url")"

    if [ -z "$keys" ]; then
        echo "No SSH public keys found for Launchpad account '$launchpad_id'." >&2
        exit 1
    fi

    sudo mkdir -p "/home/$SUPPORT_USER/.ssh"
    sudo touch "/home/$SUPPORT_USER/.ssh/authorized_keys"

    # Remove keys imported by a previous run
    sudo sed -i \
        '/# BEGIN NGROK_REMOTE_SUPPORT_LAUNCHPAD_KEYS/,/# END NGROK_REMOTE_SUPPORT_LAUNCHPAD_KEYS/d' \
        "/home/$SUPPORT_USER/.ssh/authorized_keys"

    {
        echo "# BEGIN NGROK_REMOTE_SUPPORT_LAUNCHPAD_KEYS"
        echo "$keys"
        echo "# END NGROK_REMOTE_SUPPORT_LAUNCHPAD_KEYS"
    } | sudo tee -a \
        "/home/$SUPPORT_USER/.ssh/authorized_keys" >/dev/null

    sudo chown -R \
        "$SUPPORT_USER:$SUPPORT_USER" \
        "/home/$SUPPORT_USER/.ssh"

    sudo chmod 700 \
        "/home/$SUPPORT_USER/.ssh"

    sudo chmod 600 \
        "/home/$SUPPORT_USER/.ssh/authorized_keys"

    echo "Launchpad public keys successfully imported."

else

    echo "[7/9] No Launchpad account specified."
    echo "Skipping SSH public key import."

fi

# ------------------------------------------------------------
# Configure ngrok token
# ------------------------------------------------------------
echo
echo "[8/9] Configuring ngrok..."

ngrok config add-authtoken "$token"

# ------------------------------------------------------------
# Create systemd service
# ------------------------------------------------------------
echo
echo "[9/9] Creating ngrok systemd service..."

if [ -n "$ngrok_url" ]; then
    NGROK_EXEC="$NGROK_BIN tcp --url=$ngrok_url 22"
else
    NGROK_EXEC="$NGROK_BIN tcp 22"
fi

sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=ngrok SSH Tunnel
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=$RUN_USER
Environment=HOME=$RUN_HOME
WorkingDirectory=$RUN_HOME

ExecStart=$NGROK_EXEC

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling $SERVICE_NAME.service..."
sudo systemctl enable "$SERVICE_NAME.service"

echo "Starting $SERVICE_NAME.service..."
sudo systemctl restart "$SERVICE_NAME.service"

sleep 2

# ------------------------------------------------------------
# Check service
# ------------------------------------------------------------
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    echo
    echo "ngrok service is running."
else
    echo
    echo "ngrok service failed to start." >&2
    echo
    sudo systemctl status "$SERVICE_NAME.service" --no-pager
    exit 1
fi

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
echo
echo "=========================================="
echo " Remote Support Ready"
echo "=========================================="
echo
echo "SSH username:"
echo "  $SUPPORT_USER"
echo
echo "sudo:"
echo "  NOPASSWD enabled"
echo
echo "ngrok service:"
echo "  $SERVICE_NAME.service"
echo
echo "ngrok command:"
echo "  $NGROK_EXEC"
echo

if [ -n "$launchpad_id" ]; then
    echo "Launchpad account:"
    echo "  $launchpad_id"
    echo
fi

if [ -n "$ngrok_url" ]; then
    echo "Configured ngrok endpoint:"
    echo "  $ngrok_url"
    echo
fi

echo "Useful commands:"
echo
echo "  Check status:"
echo "    systemctl status $SERVICE_NAME"
echo
echo "  Watch ngrok log:"
echo "    journalctl -u $SERVICE_NAME -f"
echo
echo "  Restart tunnel:"
echo "    sudo systemctl restart $SERVICE_NAME"
echo
echo "  Stop tunnel:"
echo "    sudo systemctl stop $SERVICE_NAME"
echo
echo "  Disable auto-start:"
echo "    sudo systemctl disable $SERVICE_NAME"
echo
echo "=========================================="
