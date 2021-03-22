#!/bin/bash

# https://github.com/lightningnetwork/lnd/releases/
LNDVERSION="v0.12.1-beta"

# help
if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo "script to install LND"
  echo "the default version is: $LNDVERSION"
  echo "install.lnd.sh [on<nodenumber>|off<nodenumber><purge>]"
  exit 1
fi

# vars
if [ -f /home/joinmarket/joinin.conf ];then
  source /home/joinmarket/joinin.conf
  NETWORK=$network
fi
if [ -f /mnt/hdd/raspiblitz.conf ];then
  source /mnt/hdd/raspiblitz.conf
  runningEnv="raspiblitz"
  NETWORK=${chain}net
fi
TORGROUP="debian-tor"
LNDUSER="bitcoin"
if [ ${#2} -eq 0 ]||[ $2 = purge ];then
  NODENUMBER=1
else
  NODENUMBER="$2"
fi
if [ ${#NODENUMBER} -eq 0 ]||[ ${NODENUMBER} = "" ];then
  echo "# Must use a node number"
  exit 1
fi
if [ $runningEnv = raspiblitz ];then
  APPDATADIR="/mnt/hdd/app-data"
elif [ $runningEnv = standalone ];then
  addUserStore
  APPDATADIR="/home/store/app-data"
fi
if [ $runningEnv = standalone ];then
  BITCOINDIR="/home/${LNDUSER}/bitcoin"
  BTCCONFPATH="/home/${LNDUSER}/.bitcoin/bitcoin.conf"
elif [ $runningEnv = raspiblitz ];then
  BITCOINDIR="/usr/local/bin"
  BTCCONFPATH="/home/bitcoin/.bitcoin/bitcoin.conf"
fi

echo
echo "NODENUMBER=$NODENUMBER"
echo "NETWORK=$NETWORK"
echo "LNDUSER=$LNDUSER"
echo "TORGROUP=$TORGROUP"
echo "APPDATADIR=$APPDATADIR"
echo "BITCOINDIR=$BITCOINDIR"
echo "BTCCONFPATH=$BTCCONFPATH"
echo
echo "# Running the command: 'install.lnd.sh $*'"
echo "# Press ENTER to continue or CTRL+C to exit"
read key

if [ "$1" = on ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
  if [ ! -f /usr/local/bin/lnd ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
    rm -rf lnd.update.${LNDVERSION}.sh
    # download
    wget https://raw.githubusercontent.com/openoms/lightning-node-management/master/lnd.updates/lnd.update.${LNDVERSION}.sh
    # look through the script
    cat lnd.update.${LNDVERSION}.sh || exit 1
    # run
    chmod +x lnd.update.${LNDVERSION}.sh || exit 1
    ./lnd.update.${LNDVERSION}.sh || exit 1
  fi

  if [ $(grep -c zmqpubrawblock < $BTCCONFPATH) -eq 0 ];then
    echo "# Configure bitcoind ZMQ"
    echo "
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
" | sudo tee -a $BTCCONFPATH
    echo "# Restart bitcoind"
    sudo systemctl restart bitcoind
    fi

  # config
  echo "# Make sure ${LNDUSER} is in the ${TORGROUP} group"
  sudo usermod -a -G ${TORGROUP} ${LNDUSER}

  echo "# Store the lightning data in $APPDATADIR/.lnd${NODENUMBER}"
  echo "# Symlink to /home/${LNDUSER}/"
  # not a symlink, delete
  sudo rm -rf /home/${LNDUSER}/.lnd${NODENUMBER}
  sudo mkdir -p $APPDATADIR/.lnd${NODENUMBER}
  sudo ln -s $APPDATADIR/.lnd${NODENUMBER} /home/${LNDUSER}/
  echo "# Create /home/${LNDUSER}/.lnd${NODENUMBER}/config"
  if [ ! -f /home/${LNDUSER}/.lnd${NODENUMBER}/config ];then
    echo "
# lnd${NODENUMBER} configuration for $NETWORK

[Application Options]
# alias=ALIAS # up to 32 UTF-8 characters
# color=COLOR # choose from: https://www.color-hex.com/
listen=0.0.0.0:97${NODENUMBER}6
rpclisten=0.0.0.0:100${NODENUMBER}9
restlisten=0.0.0.0:808${NODENUMBER}
accept-keysend=true
nat=false
debuglevel=debug
gc-canceled-invoices-on-startup=true 
gc-canceled-invoices-on-the-fly=true 
ignore-historical-gossip-filters=1 
sync-freelist=true
stagger-initial-reconnect=true
tlsautorefresh=1
tlsdisableautofill=1
tlscertpath=/home/${LNDUSER}/.lnd${NODENUMBER}/tls.cert
tlskeypath=/home/${LNDUSER}/.lnd${NODENUMBER}/tls.key

[Bitcoin]
bitcoin.active=1
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.estimatemode=ECONOMICAL

[Wtclient]
wtclient.active=1

[Tor]
tor.active=true
tor.streamisolation=true
tor.v3=true
" | sudo tee /home/${LNDUSER}/.lnd${NODENUMBER}/lnd.conf
  else
    echo "# The file /home/${LNDUSER}/.lnd${NODENUMBER}/lnd.conf is already present"
  fi
  sudo chown -R ${LNDUSER}:${LNDUSER} $APPDATADIR/.lnd${NODENUMBER}
  sudo chown -R ${LNDUSER}:${LNDUSER} /home/${LNDUSER}/  

  # systemd service
  sudo systemctl stop lnd${NODENUMBER}
  echo "# Create /etc/systemd/system/.lnd${NODENUMBER}.service"
  echo "
[Unit]
Description=LND${NODENUMBER} on $NETWORK

[Service]
User=${LNDUSER}
Group=${LNDUSER}
Type=simple
ExecStart=/usr/local/bin/lnd \
  --lnddir="/home/${LNDUSER}/.lnd${NODENUMBER}/" \
  --bitcoin.$NETWORK
KillMode=process
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/lnd${NODENUMBER}.service
  sudo systemctl daemon-reload
  sudo systemctl enable lnd${NODENUMBER}
  sudo systemctl start lnd${NODENUMBER}
  echo "# OK - the lnd${NODENUMBER}.service is now enabled and started"
  echo
  echo "# Adding aliases for $runningEnv"
  if [ $runningEnv = standalone ];then
    if [ $(grep -c "sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli" < /home/joinmarket/_commands.sh ) -eq 0 ];then
        echo "alias bitcoin-cli=\"sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli\"
alias bcli=\"sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli -network=$NETWORK\"\
" | sudo tee -a /home/joinmarket/_commands.sh
    fi
    ALIASFILE="/home/joinmarket/_commands.sh"
  elif [ $runningEnv = raspiblitz ];then
    ALIASFILE="/home/admin/_commands.sh"
  fi
  echo "alias lncli${NODENUMBER}=\"sudo -u ${LNDUSER} /usr/local/bin/lncli\
 --lnddir=\"/home/${LNDUSER}/.lnd${NODENUMBER}/\"\
 --network=$NETWORK\
 --rpcserver localhost:100${NODENUMBER}9\"" | sudo tee -a $ALIASFILE

  echo "# To activate the aliases reopen the terminal or use 'source $ALIASFILE'"
  echo
  echo "# The installed LND version is: $(sudo -u ${LNDUSER} /usr/local/bin/lnd --version)"
  echo 
  echo "# Monitor the lnd${NODENUMBER} with:"
  echo "# 'sudo journalctl -fu lnd${NODENUMBER}'"
  echo "# 'sudo systemctl status lnd${NODENUMBER}'"
  echo "# logs: 'sudo tail -f /home/bitcoin/.lnd1/logs/bitcoin/$NETWORK/lnd.log'"
  echo "# Use: 'lncli${NODENUMBER} help' for the command line options"
  echo
fi

if [ "$1" = "off" ];then
  echo "# Removing the lnd${NODENUMBER}.service"
  sudo systemctl disable lnd${NODENUMBER}
  sudo systemctl stop lnd${NODENUMBER}
  echo "# Removing the aliases"
  if [ $runningEnv = standalone ];then
    ALIASFILE="/home/joinmarket/_commands.sh"
  elif [ $runningEnv = raspiblitz ];then
    ALIASFILE="/home/admin/_commands.sh"
  fi
  sudo sed -i "/lncli${NODENUMBER}/d" $ALIASFILE
  if [ "$(echo "$@" | grep -c purge)" -gt 0 ];then
    echo "# Removing the binaries"
    sudo rm -f /usr/local/bin/lnd
    sudo rm -f /usr/local/bin/lncli
  fi
fi