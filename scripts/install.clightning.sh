#!/bin/bash
# https://lightning.readthedocs.io/

# vars
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh
# https://github.com/ElementsProject/lightning/releases
CLVERSION=v0.9.3
TORGROUP="debian-tor"
# run with the same user as bitcoin for bitcoin-cli access
if [ $network = signet ];then
  LIGHTNINGUSER="joinmarket"
  BITCOINDIR="/home/${LIGHTNINGUSER}/bitcoin"
  APPDATADIR="/mnt/hdd/app-data"
else
  LIGHTNINGUSER="bitcoin"
  if [ $runningEnv = standalone ];then
    BITCOINDIR="/home/${LIGHTNINGUSER}/bitcoin"
  elif [ $runningEnv = raspiblitz ];then
    BITCOINDIR="/usr/local/bin/"
  fi
fi
if [ $network = mainnet ]; then
  NETWORK=bitcoin
else
  NETWORK=$network
    if [ $runningEnv = standalone ];then
    addUserStore
    APPDATADIR="/home/store/app-data"
  elif [ $runningEnv = raspiblitz ];then
    APPDATADIR="/mnt/hdd/app-data"
  fi
fi

# help
if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo "script to install C-lightning $CLVERSION"
  echo "install.clightning.sh [on<number>|off<number><purge>]"
  echo
  echo "NETWORK = $NETWORK"
  echo "LIGHTNINGUSER=$LIGHTNINGUSER"
  echo "TORGROUP=$TORGROUP"
  echo "BITCOINDIR=$BITCOINDIR"
  exit 1
fi
echo
echo "# Running the command: 'install.clightning.sh $*'"
NODENUMBER="$2"
if [ ${#NODENUMBER} -eq 0 ] || [ $2 = purge ]; then
  NODENUMBER=""
fi

if [ "$1" = on ];then
  if [ -f /usr/local/bin/lightningd ];then
    installedVersion=$(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)
    echo "# C-lightning ${installedVersion} is already installed"
  else
    # dependencies
    echo "# apt update"
    echo
    sudo apt-get update
    echo
    echo "# Installing dependencies"
    echo
    sudo apt-get install -y \
    autoconf automake build-essential git libtool libgmp-dev \
    libsqlite3-dev python3 python3-mako net-tools zlib1g-dev libsodium-dev \
    gettext

    # download and compile from source
    cd /home/${LIGHTNINGUSER} || exit 1
    echo "# Cloning https://github.com/ElementsProject/lightning.git"
    echo
    sudo -u ${LIGHTNINGUSER} git clone https://github.com/ElementsProject/lightning.git
    cd lightning || exit 1
    sudo -u ${LIGHTNINGUSER} git reset --hard $CLVERSION
    sudo -u ${LIGHTNINGUSER} ./configure
    echo
    echo "# Building from source"
    echo
    sudo -u ${LIGHTNINGUSER} make
    echo
    echo "# Install to /usr/local/bin/"
    echo
    sudo make install || exit 1
    
    # clean up
    # cd .. && rm -rf lightning
  fi

  # config
  echo "# Make sure ${LIGHTNINGUSER} is in the ${TORGROUP} group"
  sudo usermod -a -G ${TORGROUP} ${LIGHTNINGUSER}
  if [ $runningEnv = standalone ];then
    addUserStore
    APPDATADIR="/home/store/app-data"
  elif [ $runningEnv = raspiblitz ];then
    APPDATADIR="/mnt/hdd/app-data"
  fi
  echo "# Store the lightning data in $APPDATADIR/.lightning${NODENUMBER}"
  echo "# Symlink to /home/${LIGHTNINGUSER}/"
  # not a symlink, delete
  sudo rm -rf /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}
  sudo mkdir -p $APPDATADIR/.lightning${NODENUMBER}
  sudo ln -s $APPDATADIR/.lightning${NODENUMBER} /home/${LIGHTNINGUSER}/
  echo "# Create /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config"
  echo "
# c-lightningd configuration for $NETWORK

log-level=debug
network=$NETWORK
announce-addr=127.0.0.1:9736${NODENUMBER}

# Tor settings
proxy=127.0.0.1:9050
bind-addr=127.0.0.1:9736${NODENUMBER}
addr=statictor:127.0.0.1:9051
always-use-proxy=true
" | sudo tee /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config
  sudo chown -R ${LIGHTNINGUSER}:${LIGHTNINGUSER} $APPDATADIR/.lightning${NODENUMBER}
  sudo chown -R ${LIGHTNINGUSER}:${LIGHTNINGUSER} /home/${LIGHTNINGUSER}/  

  # systemd service
  sudo systemctl stop lightningd${NODENUMBER}
  echo "# Create /etc/systemd/system/lightningd${NODENUMBER}.service"
  echo "
[Unit]
Description=c-lightning daemon ${NODENUMBER} on $NETWORK

[Service]
User=${LIGHTNINGUSER}
Group=${LIGHTNINGUSER}
Type=simple
Environment=PATH=\$PATH:$BITCOINDIR 
ExecStart=/usr/local/bin/lightningd --lightning-dir="/home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/"
KillMode=process
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/lightningd${NODENUMBER}.service
  sudo systemctl daemon-reload
  sudo systemctl enable lightningd${NODENUMBER}
  sudo systemctl start lightningd${NODENUMBER}
  echo "# OK - the lightningd${NODENUMBER}.service is now enabled and started"
  echo
  echo "# Adding aliases"
  echo "
alias bitcoin-cli=\"sudo -u ${LIGHTNINGUSER} $BITCOINDIR/bitcoin-cli\"
alias bcli=\"sudo -u ${LIGHTNINGUSER} $BITCOINDIR/bitcoin-cli -network=$NETWORK\"

alias lightning-cli${NODENUMBER}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\"
alias cl${NODENUMBER}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\"
" | sudo tee -a /home/joinmarket/_commands.sh

  echo "# To activate the aliases reopen the terminal or use 'source /home/joinmarket/_commands.sh'"
  echo
  echo "# Installed C-lightning $(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)"
  echo 
  echo "# Monitor the lightningd${NODENUMBER} with:"
  echo "# 'sudo journalctl -fu lightningd${NODENUMBER}'"
  echo "# 'sudo systemctl status lightningd${NODENUMBER}'"
  echo "# Use: 'lightning-cli${NODENUMBER} help' for the command line options"
  echo
fi

if [ "$1" = "off" ];then
  echo "# Removing the lightningd.service"
  sudo systemctl disable lightningd${NODENUMBER}
  sudo systemctl stop lightningd${NODENUMBER}
  echo "# Removing the aliases"
  sudo sed -i "s#alias bitcoin-cli=\"sudo -u .* /home/.*/bitcoin/bitcoin-cli\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias bcli=\"sudo -u .* /home/.*/bitcoin/bitcoin-cli -network=.*\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias lightning-cli${NODENUMBER}=\"sudo -u .* /usr/local/bin/lightning-cli\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias cl${NODENUMBER}=\"sudo -u .* /usr/local/bin/lightning-cli\"##g" /home/joinmarket/_commands.sh
  if [ "$(echo "$@" | grep -c purge)" -gt 0 ];then
    echo "# Removing the binaries"
    sudo rm -f /usr/local/bin/lightningd
    sudo rm -f /usr/local/bin/lightning-cli
  fi
fi