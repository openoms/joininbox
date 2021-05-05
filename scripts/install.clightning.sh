#!/bin/bash
# https://lightning.readthedocs.io/

# https://github.com/ElementsProject/lightning/releases
CLVERSION=v0.10.0

# help
if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo "script to install C-lightning"
  echo "the default version is: $CLVERSION"
  echo "install.clightning.sh [on<nodenumber>|update<version>|commit|testPR<PRnumber>|off<nodenumber><purge>]"
  exit 1
fi

# vars
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh
TORGROUP="debian-tor"
# run with the same user as bitcoin for bitcoin-cli access
if [ $network = signet ];then
  LIGHTNINGUSER="joinmarket"
  BITCOINDIR="/home/${LIGHTNINGUSER}/bitcoin"
else
  LIGHTNINGUSER="bitcoin"
  if [ $runningEnv = standalone ];then
    BITCOINDIR="/home/${LIGHTNINGUSER}/bitcoin"
  elif [ $runningEnv = raspiblitz ];then
    BITCOINDIR="/usr/local/bin"
  fi
fi
if [ ${#2} -eq 0 ]||[ $2 = purge ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
  NODENUMBER=""
else
  NODENUMBER="$2"
fi
if [ $network = mainnet ];then
  NETWORK=bitcoin
else
  NETWORK=$network
fi
if [ $runningEnv = standalone ];then
    addUserStore
    APPDATADIR="/home/store/app-data"
elif [ $runningEnv = raspiblitz ];then
    APPDATADIR="/mnt/hdd/app-data"
fi

echo
echo "NODENUMBER=$NODENUMBER"
echo "NETWORK=$NETWORK"
echo "LIGHTNINGUSER=$LIGHTNINGUSER"
echo "TORGROUP=$TORGROUP"
echo "BITCOINDIR=$BITCOINDIR"
echo "APPDATADIR=$APPDATADIR"
echo
echo "# Running the command: 'install.clightning.sh $*'"
echo "# Press ENTER to continue or CTRL+C to exit"
read key

if [ "$1" = on ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
  if [ ! -f /usr/local/bin/lightningd ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
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
    if [ "$1" = "update" ] || [ "$1" = "testPR" ] || [ "$1" = "commit" ]; then
      echo
      echo "# Deleting the old source code"
      echo
      sudo rm -rf lightning
    fi
    echo
    echo "# Cloning https://github.com/ElementsProject/lightning.git"
    echo
    sudo -u ${LIGHTNINGUSER} git clone https://github.com/ElementsProject/lightning.git
    cd lightning || exit 1
    
    if [ "$1" = "testPR" ]; then
      PRnumber=$2 || exit 1
      echo
      echo "# Using the PR:"
      echo "# https://github.com/ElementsProject/lightning/pull/$PRnumber"
      echo
      sudo -u ${LIGHTNINGUSER} git fetch origin pull/$PRnumber/head:pr$PRnumber || exit 1
      sudo -u ${LIGHTNINGUSER} git checkout pr$PRnumber || exit 1
      echo "# Building with EXPERIMENTAL_FEATURES enabled"
      sudo -u ${LIGHTNINGUSER} ./configure --enable-experimental-features
    elif [ "$1" = "commit" ]; then
      echo
      echo "# Updating to the latest commit in:"
      echo "# https://github.com/ElementsProject/lightning"
      echo
      echo "# Building with EXPERIMENTAL_FEATURES enabled"
      sudo -u ${LIGHTNINGUSER} ./configure --enable-experimental-features
    else
      if [ "$1" = "update" ]; then
        CLVERSION=$2
        echo "# Updating to the version $CLVERSION"
      fi
      sudo -u ${LIGHTNINGUSER} git reset --hard $CLVERSION
      sudo -u ${LIGHTNINGUSER} ./configure
    fi

    currentCLversion=$(cd /home/${LIGHTNINGUSER}/lightning 2>/dev/null; \
    git describe --tags 2>/dev/null)
    sudo -u ${LIGHTNINGUSER} ./configure
    echo
    echo "# Building from source C-lightning $currentCLversion"
    echo
    sudo -u ${LIGHTNINGUSER} make
    echo
    echo "# Built C-lightning $currentCLversion"
    echo
    echo "# Install to /usr/local/bin/"
    echo
    sudo make install || exit 1
    # clean up
    # cd .. && rm -rf lightning
  else
    installedVersion=$(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)
    echo "# C-lightning ${installedVersion} is already installed"
  fi

  # config
  echo "# Make sure ${LIGHTNINGUSER} is in the ${TORGROUP} group"
  sudo usermod -a -G ${TORGROUP} ${LIGHTNINGUSER}

  echo "# Store the lightning data in $APPDATADIR/.lightning${NODENUMBER}"
  echo "# Symlink to /home/${LIGHTNINGUSER}/"
  # not a symlink, delete
  sudo rm -rf /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}
  sudo mkdir -p $APPDATADIR/.lightning${NODENUMBER}
  sudo ln -s $APPDATADIR/.lightning${NODENUMBER} /home/${LIGHTNINGUSER}/
  echo "# Create /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config"
  if [ ! -f /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config ];then
    echo "
# lightningd${NODENUMBER} configuration for $NETWORK

network=$NETWORK
announce-addr=127.0.0.1:9736${NODENUMBER}
log-file=cl${NODENUMBER}.log
log-level=debug

# Tor settings
proxy=127.0.0.1:9050
bind-addr=127.0.0.1:9736${NODENUMBER}
addr=statictor:127.0.0.1:9051
always-use-proxy=true
" | sudo tee /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config
  else
    echo "# The file /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config is already present"
  fi
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
ExecStart=/usr/local/bin/lightningd \
  --lightning-dir="/home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/"
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
  if [ $(grep -c "sudo -u ${LIGHTNINGUSER} $BITCOINDIR/bitcoin-cli" < /home/joinmarket/_commands.sh ) -eq 0 ];then
    echo "\
alias bitcoin-cli=\"sudo -u ${LIGHTNINGUSER} $BITCOINDIR/bitcoin-cli\"
alias bcli=\"sudo -u ${LIGHTNINGUSER} $BITCOINDIR/bitcoin-cli -network=$NETWORK\"\
" | sudo tee -a /home/joinmarket/_commands.sh
  fi
  echo "\
alias lightning-cli${NODENUMBER}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\
 --conf=/home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config\
 --lightning-dir=/home/${LIGHTNINGUSER}/.lightning${NODENUMBER} \"
alias cl${NODENUMBER}=\"sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightning-cli\
 --conf=/home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/config\
 --lightning-dir=/home/${LIGHTNINGUSER}/.lightning${NODENUMBER} \"\
" | sudo tee -a /home/joinmarket/_commands.sh

  echo "# To activate the aliases reopen the terminal or use 'source /home/joinmarket/_commands.sh'"
  echo
  echo "# The installed C-lightning version is: $(sudo -u ${LIGHTNINGUSER} /usr/local/bin/lightningd --version)"
  echo 
  echo "# Monitor the lightningd${NODENUMBER} with:"
  echo "# 'sudo journalctl -fu lightningd${NODENUMBER}'"
  echo "# 'sudo systemctl status lightningd${NODENUMBER}'"
  echo "# logs: 'tail -f /home/${LIGHTNINGUSER}/.lightning${NODENUMBER}/${NETWORK}/cl${NODENUMBER}.log'"
  echo "# Use: 'lightning-cli${NODENUMBER} help' for the command line options"
  echo
fi

if [ "$1" = "off" ];then
  echo "# Removing the lightningd.service"
  sudo systemctl disable lightningd${NODENUMBER}
  sudo systemctl stop lightningd${NODENUMBER}
  echo "# Removing the aliases"
  #sudo sed -i "s#alias bitcoin-cli=\"sudo -u .* /home/${LIGHTNINGUSER}/bitcoin/bitcoin-cli\"##g" /home/joinmarket/_commands.sh
  #sudo sed -i "s#alias bcli=\"sudo -u .* /home/${LIGHTNINGUSER}/bitcoin/bitcoin-cli -network=$NETWORK\"##g" /home/joinmarket/_commands.sh
  sudo sed -i "/lightning-cli${NODENUMBER}/d" /home/joinmarket/_commands.sh
  sudo sed -i "/cl${NODENUMBER}/d" /home/joinmarket/_commands.sh
  if [ "$(echo "$@" | grep -c purge)" -gt 0 ];then
    echo "# Removing the binaries"
    sudo rm -f /usr/local/bin/lightningd
    sudo rm -f /usr/local/bin/lightning-cli
  fi
fi