#!/bin/bash
# https://lightning.readthedocs.io/

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# https://github.com/ElementsProject/lightning/releases
CLVERSION=v0.9.3
TORGROUP="debian-tor"
# run with the same user as bitcoin for bitcoin-cli access
if [ $network = signet ];then
  LIGHTNINGUSER="joinmarket"
else
  LIGHTNINGUSER="bitcoin"
fi

if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo "script to install C-lightning $CLVERSION"
  echo "install.clightning.sh [on<number>|off<number><purge>]"
  echo
  echo "network = $network"
  echo "LIGHTNINGUSER=$LIGHTNINGUSER"
  echo "TORGROUP=$TORGROUP"
  exit 1
fi

echo "# Running the command: 'install.clightning.sh $*'"

NODENAME="$2"
if [ ${#NODENAME} -eq 0 ] || [ $2 = purge ]; then
  NODENAME=""
fi

if [ "$1" = on ];then
  if [ -f /usr/local/bin/lightningd ];then
    installedVersion=$(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)
    echo "C-lightning ${installedVersion} is already installed"
  else
    # dependencies
    sudo apt-get update
    sudo apt-get install -y \
    autoconf automake build-essential git libtool libgmp-dev \
    libsqlite3-dev python3 python3-mako net-tools zlib1g-dev libsodium-dev \
    gettext

    # download and compile from source
    cd /home/${LIGHTNINGUSER} || exit 1
    sudo -u ${LIGHTNINGUSER} git clone https://github.com/ElementsProject/lightning.git
    cd lightning || exit 1
    sudo -u ${LIGHTNINGUSER} git reset --hard $CLVERSION
    sudo -u ${LIGHTNINGUSER} ./configure
    sudo -u ${LIGHTNINGUSER} make
    # install to /usr/local/bin/
    sudo make install || exit 1
    # clean up
    # cd .. && rm -rf lightning
  fi

  if [ $runningEnv = standalone ];then
    addUserStore
    APPDATADIR="/home/store/app-data"
  elif [ $runningEnv = raspiblitz ];then
    APPDATADIR="/mnt/hdd/app-data"
  fi
  # config
  # Tor access
  sudo usermod -a -G ${TORGROUP} ${LIGHTNINGUSER}
  echo "# symlink to /home/${LIGHTNINGUSER}/"
  # not a symlink, delete
  sudo rm -rf /home/${LIGHTNINGUSER}/.lightning${NODENAME}
  sudo mkdir -p $APPDATADIR/.lightning${NODENAME}
  sudo ln -s $APPDATADIR/.lightning${NODENAME} /home/${LIGHTNINGUSER}/
  
  echo "
# c-lightningd configuration for $network

log-level=debug

network=$network

proxy=127.0.0.1:9050
bind-addr=127.0.0.1:9735
addr=statictor:127.0.0.1:9051
always-use-proxy=true
" | sudo tee /home/${LIGHTNINGUSER}/.lightning${NODENAME}/config
  sudo chown -R ${LIGHTNINGUSER}:${LIGHTNINGUSER} $APPDATADIR/.lightning${NODENAME}
  sudo chown -R ${LIGHTNINGUSER}:${LIGHTNINGUSER} /home/${LIGHTNINGUSER}/  

  # systemd service
  sudo systemctl stop lightningd${NODENAME}
  # /etc/systemd/system/lightningd.service
  echo "
[Unit]
Description=c-lightning daemon ${NODENAME} on $network

[Service]
User=${LIGHTNINGUSER}
Group=${LIGHTNINGUSER}
Type=simple
Environment=PATH=\$PATH:/home/${LIGHTNINGUSER}/bitcoin --lightning-dir=/home/${LIGHTNINGUSER}/.lightning${NODENAME}/
ExecStart=/usr/local/bin/lightningd 
KillMode=process
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/lightningd${NODENAME}.service
  sudo systemctl daemon-reload
  sudo systemctl enable lightningd${NODENAME}
  sudo systemctl start lightningd${NODENAME}
  echo "# OK - the lightningd${NODENAME}.service is now enabled and started"
  echo
  echo "# Adding aliases"
  echo "
alias bitcoin-cli=\"sudo -u ${LIGHTNINGUSER} /home/${LIGHTNINGUSER}/bitcoin/bitcoin-cli\"
alias bcli=\"sudo -u ${LIGHTNINGUSER} /home/${LIGHTNINGUSER}/bitcoin/bitcoin-cli -network=$network\"

alias lightning-cli${NODENAME}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\"
alias cl${NODENAME}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\"
" | sudo tee -a /home/joinmarket/_commands.sh

  echo "# To activate the aliases reopen the terminal or use 'source /home/joinmarket/_commands.sh'"
  echo
  echo "# Installed C-lightning $(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)"
  echo 
  echo "# Monitor the lightningd${NODENAME} with:"
  echo "# 'sudo journalctl -fu lightningd${NODENAME}'"
  echo "# 'sudo systemctl status lightningd${NODENAME}'"
  echo "# Use: 'lightning-cli${NODENAME} help' for the command line options"
  echo
fi

if [ "$1" = "off" ];then
  echo "# Removing the lightningd.service"
  sudo systemctl disable lightningd${NODENAME}
  sudo systemctl stop lightningd${NODENAME}
  echo "# Removing the aliases"
  sudo sed -i "s#alias bitcoin-cli=\"sudo -u .* /home/.*/bitcoin/bitcoin-cli\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias bcli=\"sudo -u .* /home/.*/bitcoin/bitcoin-cli -network=.*\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias lightning-cli${NODENAME}=\"sudo -u .* /usr/local/bin/lightning-cli\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "s#alias cl${NODENAME}=\"sudo -u .* /usr/local/bin/lightning-cli\"##g" /home/joinmarket/_commands.sh
  if [ "$(echo "$@" | grep -c purge)" -gt 0 ];then
    echo "# Removing the binaries"
    sudo rm -f /usr/local/bin/lightningd
    sudo rm -f /usr/local/bin/lightning-cli
  fi
fi