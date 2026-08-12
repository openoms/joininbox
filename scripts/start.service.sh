#!/bin/bash

source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

script="$1"
wallet="$2"

if [ "$script" != "yg-privacyenhanced" ]; then
  echo "# Refusing unsupported service: $script" >&2
  exit 1
fi

walletInput="$wallet"
if [ -L "$walletInput" ]; then
  echo "# Refusing a symlink as wallet input" >&2
  exit 1
fi
wallet=$(readlink -f -- "$walletInput") || exit 1
walletDirectory=$(readlink -f -- "$walletPath") || exit 1
walletFileName=$(basename -- "$wallet")
case "$walletFileName" in
  ''|*[!A-Za-z0-9._-]*)
    echo "# Refusing unsafe wallet filename" >&2
    exit 1
    ;;
esac
if [ ! -f "$wallet" ] || \
  [ "$(dirname -- "$wallet")" != "$walletDirectory" ]; then
  echo "# Wallet must be a regular file directly inside $walletDirectory" >&2
  exit 1
fi

stopYG "$wallet"

if [ "${RPCoverTor}" = "on" ];then
  tor="torsocks"
else
  tor=""
fi

startScript="cat /dev/shm/.pw | $tor python $script.py $wallet \
--wallet-password-stdin"
# display
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

sudo systemctl daemon-reload
sudo systemctl enable $script
sudo systemctl start $script

echo
echo "# Shredding the password once used..."
echo

sleep 5
# delete password once used
shred -uvz /dev/shm/.pw
