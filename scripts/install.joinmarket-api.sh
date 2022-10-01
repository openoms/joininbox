#!/bin/bash

USERNAME=joinmarket
HOME_DIR=/home/$USERNAME

if [ ${#1} -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo "Script to start/stop the joinmarket-api.service."
  echo "Usage:"
  echo "start.joinmarket-api.sh [on|off]"
  echo "Display a QRcode to connect Fully Noded:"
  echo "start.joinmarket-api.sh connect"
fi

source $HOME_DIR/joinin.conf

function joinmarketApiServiceOn() {

  $HOME_DIR/install.selfsignedcert.sh

  if ! systemctl is-active --quiet joinmarket-api; then
    echo "# Install joinmarket-api.service"
    echo "# joinmarket-api.service
[Unit]
Description=JoinMarket API daemon

[Service]
WorkingDirectory=$HOME_DIR/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c '. $HOME_DIR/joinmarket-clientserver/jmvenv/bin/activate && python jmwalletd.py'
User=joinmarket
Group=joinmarket
Restart=always
TimeoutSec=120
RestartSec=60
# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/joinmarket-api.service
    sudo systemctl enable joinmarket-api
    sudo systemctl start joinmarket-api
  else
    echo "The joinmarket-api.service is already active."
  fi
}

if [ "$1" = on ]; then

  joinmarketApiServiceOn

elif [ "$1" = connect ]; then

  joinmarketApiServiceOn

  # add hidden service
  $HOME_DIR/install.hiddenservice.sh joinmarket-api 28183 28183

  # A QR code which displays the textual representation of a url in the following format:"
  #http://<hostname>.onion:28183?cert=<base64cert>
  torAddress=$(sudo cat /mnt/hdd/tor/joinmarket-api/hostname)
  base64cert=$(base64 -w 0 ${HOME_DIR}/.joinmarket/ssl/cert.pem)
  url="http://${torAddress}:28183?cert=${base64cert}"

  if [ "$runningEnv" = raspiblitz ];then
    sudo /home/admin/config.scripts/blitz.display.sh qr "${url}"
  fi
  echo
  echo "Scan the QR code below with Fully Noded to connect to JoinMarket."
  echo "Hidden Service address:"
  echo "${torAddress}:28183"
  echo "base64 cert.pem:"
  echo "${base64cert}"
  echo
  qrencode -t ANSIUTF8 "${url}"
  echo
  echo "Make this terminal window as large as possible - fullscreen would be best."
  echo "If the Qrcode is still too large shrink the letters by pressing the keys:"
  echo "Ctrl and Minus (or Cmd and Minus if you are on a Mac)"
  echo
  if [ $runningEnv = raspiblitz ];then
    echo "# Press enter to hide the QRcode from the LCD"
    read key
    sudo /home/admin/config.scripts/blitz.display.sh hide
  fi
  exit 0

elif [ "$1" = off ];then
  # remove hidden service
  $HOME_DIR/install.hiddenservice.sh off joinmarket-api

  # remove systemd service
  sudo systemctl stop joinmarket-api
  sudo systemctl disable joinmarket-api
  sudo rm -f /etc/systemd/system/joinmarket-api.service
fi