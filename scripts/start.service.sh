#!/bin/bash

# Usage: start.service.sh <script> <wallet> <passwordFile>
# (the passwordFile argument was added when the wallet password moved from
# /dev/shm/.pw to a per-run file; the old two-argument form is no longer valid)
source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

script="$1"
walletInput="$2"
passwordFile="$3"

if [ ! -f "$passwordFile" ] || [ -L "$passwordFile" ]; then
  echo "# Invalid wallet password file"
  exit 1
fi
case "$passwordFile" in
  /dev/shm/joininbox-wallet-password.*) ;;
  *)
    echo "# Wallet password file is outside the allowed runtime path"
    exit 1
    ;;
esac
# the suffix after the allowed prefix must be a plain filename
# (no '/', no '..', so path traversal cannot pass the glob)
passwordFileName="${passwordFile#/dev/shm/joininbox-wallet-password.}"
case "$passwordFileName" in
  ""|*..*|*/*)
    echo "# Wallet password file name is invalid"
    exit 1
    ;;
esac
if [ "$(stat -c '%u:%a' -- "$passwordFile")" != "$(id -u):600" ]; then
  echo "# Wallet password file has an unsafe owner or mode"
  exit 1
fi

# Validate and canonicalize ALL inputs at the very top,
# before anything touches credential files (the wallet password temp file)
# or makes any system changes.
wallet=$(validateServiceArgs "$script" "$walletInput") || exit 1

stopYG "$wallet"

if [ "${RPCoverTor}" = "on" ];then
  tor="torsocks"
else
  tor=""
fi

startScript="cat '$passwordFile' | $tor python $script.py '$wallet' \
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
echo "# Deleting the password file once used..."
echo

sleep 5
# delete password once used
rm -f -- "$passwordFile"
