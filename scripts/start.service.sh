#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

script="$1"
wallet="$2"

if [ $script == "yg-privacyenhanced" ]; then
  stopYG $wallet
else
echo
  echo "# Making sure $script is not running"
  sudo systemctl stop $script
  sudo systemctl disable $script
fi

if [ "${RPCoverTor}" = "on" ];then
  tor="torsocks"
else
  tor=""
fi

startScript="cat /dev/shm/.pw | $tor python $script.py $wallet \
--wallet-password-stdin"
# display
walletFileName="${wallet//$walletPath/ }"
echo
echo "# Running the command with systemd:"
echo " $tor python $script.py $walletFileName"

echo "
[Unit]
Description=$script

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c \
'. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate && $startScript'
User=joinmarket
Group=joinmarket
Type=simple
TimeoutSec=infinity
Restart=no

# Memory limits (DoS / OOM protection)
MemoryHigh=300M
MemoryMax=512M
MemorySwapMax=0

# Reduce OOM kill priority (lower = less likely to be killed)
OOMScoreAdjust=-500
OOMPolicy=stop

# CPU limit
CPUQuota=80%

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/$script.service 1>/dev/null

echo
echo "# Starting the systemd service: $script"
echo

sudo systemctl enable $script
sudo systemctl start $script

echo
echo "# Shredding the password once used..."
echo

sleep 5
# delete password once used
shred -uvz /dev/shm/.pw
