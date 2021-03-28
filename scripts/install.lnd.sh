#!/bin/bash

# https://github.com/lightningnetwork/lnd/releases/
LNDVERSION="v0.12.1-beta"

# help
if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo 
  echo "script to install a LND"
  echo "Do not connect more than 3 instances to a bitcoin node!"
  echo "the default version is: $LNDVERSION"
  echo "the nodenumber defaults to '1'"
  echo "Usage:"
  echo "install.lnd.sh [on <nodenumber>|off <nodenumber> <purge>]"
  echo
  echo "to add the node to BoS, ThunderHub, Sphinx or export macaroons & tls.cert:"
  echo "install.lnd.sh menu"
  echo "install.lnd.sh [bos|sphinx|thunderhub|hexstring|scp|http|btcpay <nodenumber>]"
  echo
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

if [ "$1" = on ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
  echo "# Press ENTER to continue or CTRL+C to exit"
  read key

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

##########
# EXPORT #
##########
if [ "$1" =  menu ]||[ "$1" =  hexstring ]||[ "$1" =  scp ]||\
   [ "$1" =  http ]||[ "$1" =  btcpay ]||[ "$1" =  bos ]||\
   [ "$1" =  thunderhub ]||[ "$1" =  sphinx ];then
  # 1. parameter -> the type of export
  exportType=$1
  # interactive choose type of export if not set
  if [ "$1" = "menu" ]; then
      OPTIONS=()
      OPTIONS+=(THUB "Add lnd${NODENUMBER} to ThunderHub")
      OPTIONS+=(SPHINX "Set lnd${NODENUMBER} in Sphinx-relay")
      if [ ${#bos} -gt 0 ] && [ $bos = on ] && \
      [ $(systemctl status lnd${NODENUMBER} | grep -c active) -gt 0 ];then
        OPTIONS+=(BOS "Add lnd${NODENUMBER} to Balance of Satoshis") 
      fi
      OPTIONS+=(SCP "SSH Download (Commands)")
      OPTIONS+=(HTTP "Browserdownload (bit risky)")
      OPTIONS+=(HEX "Hex-String (Copy+Paste)")   
      OPTIONS+=(STR "BTCPay Connection String") 

      CHOICE=$(dialog --clear \
                  --backtitle "RaspiBlitz" \
                  --title "Export Macaroons & TLS.cert" \
                  --menu "How do you want to export?" \
                  14 50 8 \
                  "${OPTIONS[@]}" \
                  2>&1 >/dev/tty)
      clear
      case $CHOICE in
        HEX)
          exportType='hexstring';;
        STR)
          exportType='btcpay';;
        SCP)
          exportType='scp';;
        HTTP)
          exportType='http';;
        THUB)
          exportType='thunderhub';;
        BOS)
          exportType='bos';;
        SPHINX)
          exportType='sphinx';;
      esac
  fi
  # load data from config
  source /home/admin/raspiblitz.info
  source /mnt/hdd/raspiblitz.conf
  # CANCEL
  if [ ${#exportType} -eq 0 ]; then
    echo "CANCEL"
    exit 0

  ########################
  # HEXSTRING
  ########################
  elif [ "${exportType}" = "hexstring" ]; then
    clear
    echo "###### HEXSTRING EXPORT ######"
    echo ""
    echo "admin.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/admin.macaroon
    echo ""
    echo "invoice.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/invoice.macaroon
    echo ""
    echo "readonly.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/readonly.macaroon
    echo ""
    echo "tls.cert:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/tls.cert
    echo

  ########################
  # BTCPAY Connection String
  ########################
  elif [ "${exportType}" = "btcpay" ]; then
    # take public IP as default
    # TODO: IP2TOR --> check if there is a forwarding for LND REST oe ask user to set one up
    #ip="${publicIP}"
    ip="127.0.0.1"
    port="808${NODENUMBER}"
    # will overwrite ip & port if IP2TOR tunnel is available
    source <(sudo /home/admin/config.scripts/blitz.subscriptions.ip2tor.py subscription-by-service LND-REST-API)
    # bake macaroon that just can create invoices and monitor them
    macaroon=$(lncli${NODENUMEBR} bakemacaroon address:read address:write info:read invoices:read invoices:write onchain:read)
    # get certificate thumb
    certthumb=$(sudo openssl x509 -noout -fingerprint -sha256 -inform pem -in /home/bitcoin/.lnd${NODENUMBER}/tls.cert | cut -d "=" -f 2)
    # construct connection string
    connectionString="type=lnd-rest;server=https://${ip}:${port}/;macaroon=${macaroon};certthumbprint=${certthumb}"
    clear
    echo "###### BTCPAY CONNECTION STRING ######"
    echo ""
    echo "${connectionString}"
    echo ""
    # add info about outside reachability (type would have a value if IP2TOR tunnel was found)
    if [ ${#type} -gt 0 ]; then
      echo "NOTE: You have a IP2TOR connection for LND REST API .. so you can use this connection string also with a external BTCPay server."
    else
      echo "IMPORTANT: You can only use this connection string for a BTCPay server running on this RaspiBlitz."
      echo "If you want to connect from a external BTCPay server activate a IP2TOR tunnel for LND-REST first:"
      echo "MAIN MENU > SUBSCRIBE > IP2TOR > LND REST API"
      echo "Then come back and get a new connection string."
    fi
    echo

  ###########################
  # SHH / SCP File Download
  ###########################
  elif [ "${exportType}" = "scp" ]; then
    local_ip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0|veth' | grep 'eth0\|wlan0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    clear
    echo "###### DOWNLOAD BY SCP ######"
    echo "Copy, paste and execute these commands in your client terminal to download the files."
    echo "The password needed during download is your Password A."
    echo ""
    echo "Macaroons:"
    echo "scp bitcoin@${local_ip}:/home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/\*.macaroon ./"
    echo ""
    echo "TLS Certificate:"
    echo "scp bitcoin@${local_ip}:/home/bitcoin/.lnd${NODENUMBER}/tls.cert ./"
    echo ""

  ###########################
  # HTTP File Download
  ###########################
  elif [ "${exportType}" = "http" ]; then
    local_ip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0|veth' | grep 'eth0\|wlan0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    randomPortNumber=$(shuf -i 20000-39999 -n 1)
    sudo ufw allow from 192.168.0.0/16 to any port ${randomPortNumber} comment 'temp http server'
    clear
    echo "###### DOWNLOAD BY HTTP ######"
    echo ""
    echo "Open in your browser --> http://${local_ip}:${randomPortNumber}"
    echo ""
    echo "You need to be on the same local network - not reachable from outside."
    echo "In browser click on files or use 'save as' from context menu to download."
    echo ""
    echo "Temp HTTP Server is running - use CTRL+C to stop when you are done"
    echo ""
    cd 
    randomFolderName=$(shuf -i 100000000-900000000 -n 1)
    mkdir ${randomFolderName}
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/admin.macaroon ./${randomFolderName}/admin.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/readonly.macaroon ./${randomFolderName}/readonly.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/invoice.macaroon ./${randomFolderName}/invoice.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/tls.cert ./${randomFolderName}/tls.cert
    cd ${randomFolderName}
    sudo chmod 444 *.*
    python3 -m http.server ${randomPortNumber} 2>/dev/null
    sudo ufw delete allow from 192.168.0.0/16 to any port ${randomPortNumber} comment 'temp http server'
    cd ..
    sudo rm -r ${randomFolderName}
    echo "OK - temp HTTP server is stopped."

  ##############
  # THUNDERHUB
  ##############
   elif [ "${exportType}" = "thunderhub" ]; then
    echo "
  - name: lnd${NODENUMBER}
    serverUrl: 127.0.0.1:100${NODENUMBER}9
    macaroon: '$(sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/admin.macaroon)'
    certificate: '$(sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/tls.cert)'
" | sudo tee -a /mnt/hdd/app-data/thunderhub/thubConfig.yaml
    sudo systemctl restart tunderhub
  
  #######
  # BOS #
  #######
  elif [ "${exportType}" = "bos" ];then
    echo "# Press ENTER to continue or CTRL+C to exit"
    read key
    # https://github.com/alexbosworth/balanceofsatoshis#using-saved-nodes
    sudo -u bos mkdir /home/bos/.bos/lnd${NODENUMBER}
    CERT=$(sudo base64 /home/${LNDUSER}/.lnd${NODENUMBER}/tls.cert | tr -d '\n')
    MACAROON=$(sudo base64 /home/${LNDUSER}/.lnd${NODENUMBER}/data/chain/bitcoin/mainnet/admin.macaroon | tr -d '\n')
    echo "{
  \"cert\": \"$CERT\",
  \"macaroon\": \"$MACAROON\",
  \"socket\": \"localhost:100${NODENUMBER}9\"
}" | sudo tee /home/bos/.bos/lnd${NODENUMBER}/credentials.json
    echo "# Added node to bos as: lnd${NODENUMBER}"
    echo "alias bos${NODENUMBER}=\"sudo -u bos /home/bos/.npm-global/bin/bos --node lnd${NODENUMBER}\"" | tee -a /home/admin/_commands.sh
    echo "# Added the alias: 'bos${NODENUMBER}'"
    echo "# Activate with: 'source /home/admin/_commands.sh'"
    echo "# Example to fund a channel directly:"
    echo "'bos${NODENUMBER} open <pubkey> --amount <sats>'"

  ##########
  # SPHINX #
  ##########
  elif [ "${exportType}" = "sphinx" ];then
    echo "# Press ENTER to continue or CTRL+C to exit"
    read key
  function mac_set_perms() {
    local file_name=${1}  # the file name (e.g. admin.macaroon)
    local group_name=${2} # the unix group name (e.g. lndadmin)
    local n=${3:-bitcoin} # the network (e.g. bitcoin or litecoin) defaults to bitcoin
    local c=${4:-main}    # the chain (e.g. main, test, sim, reg) defaults to main (for mainnet)
    sudo -u sphinxrelay mkdir /mnt/hdd/app-data/sphinxrelay/lnd{NODENUMBER}
    sudo /bin/cp /mnt/hdd/app-data/.lnd${NODENUMBER}/data/chain/"${n}"/"${c}"net/"${file_name}" /mnt/hdd/app-data/sphinxrelay/lnd{NODENUMBER}/"${file_name}"
    sudo /bin/chown --silent admin:"${group_name}" /mnt/hdd/app-data/sphinxrelay/lnd{NODENUMBER}/"${file_name}"
    sudo /bin/chmod --silent 640 /mnt/hdd/app-data/sphinxrelay/lnd{NODENUMBER}/"${file_name}"
  }

  function copyMacaroons() {
    echo "#  ensure unix ownerships and permissions"
    mac_set_perms admin.macaroon lndadmin "${network}" "${chain}"
    mac_set_perms router.macaroon lndrouter "${network}" "${chain}"
    mac_set_perms signer.macaroon lndsigner "${network}" "${chain}"
    echo "# OK DONE"
  }
    copyMacaroons
    sudo cat /home/sphinxrelay/sphinx-relay/connection_string.txt
    now=$(date +"%Y_%m_%d_%H%M%S")
    echo "# Will backup your existing Sphinx database to sphinx.backup${now}.db"
    echo "Press ENTER to continue or CTRL+C to abort"
    read key
    sudo mv /home/sphinxrelay/sphinx-relay/connection_string.txt /home/sphinxrelay/sphinx-relay/connection_string.backup$now.txt
    sudo mv -f /mnt/hdd/app-data/sphinxrelay/sphinx.db  /mnt/hdd/app-data/sphinxrelay/sphinx.backup${now}.db

    sudo chmod +x $HOME/install.lnd.sh
    sudo -u sphinxrelay $HOME/install.lnd.sh write-sphinx-environment
    if [ $(grep -c write-sphinx-environment < /etc/systemd/system/sphinxrelay.service) -eq 0 ];then
      sudo systemctl stop sphinxrelay
      echo "
[Unit]
Description=SphinxRelay
Wants=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/home/sphinxrelay/sphinx-relay
ExecStartPre=$HOME/install.lnd.sh write-sphinx-environment
ExecStart=env NODE_ENV=production /usr/bin/node dist/app.js
User=sphinxrelay
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
  " | sudo tee /etc/systemd/system/sphinxrelay.service
      sudo systemctl daemon-reload
      sudo systemctl start sphinxrelay
    else
      sudo systemctl restart sphinxrelay
    fi
    sleep 10
    sudo cat /home/sphinxrelay/sphinx-relay/connection_string.txt
  fi
fi

if [ "$1" =  write-sphinx-environment ];then
  # !! all this needs to run (be called as) user: sphinxrelay
  # get basic data from status
  source <(/home/admin/config.scripts/bonus.sphinxrelay.sh status)
  # database config
  cat /home/sphinxrelay/sphinx-relay/config/config.json | \
  jq ".production.storage = \"/mnt/hdd/app-data/sphinxrelay/sphinx.db\"" > /home/sphinxrelay/sphinx-relay/config/config.json.tmp
  mv /home/sphinxrelay/sphinx-relay/config/config.json.tmp /home/sphinxrelay/sphinx-relay/config/config.json
  # update node ip in config
  cat /home/sphinxrelay/sphinx-relay/config/app.json | \
  jq ".production.tls_location = \"/mnt/hdd/app-data/.lnd${NODENUMBER}/tls.cert\"" | \
  jq ".production.macaroon_location = \"/mnt/hdd/app-data/sphinxrelay/lnd{NODENUMBER}/admin.macaroon\"" | \
  jq ".production.lnd_log_location = \"/mnt/hdd/.lnd${NODENUMBER}/logs/${network}/${chain}net/lnd.log\"" | \
  jq ".production.node_http_port = \"3300\"" | \
  jq ".production.lnd_port = \"100${NODENUMBER}9\"" | \
  jq ".production.public_url = \"${publicURL}\"" > /home/sphinxrelay/sphinx-relay/config/app.json.tmp
  mv /home/sphinxrelay/sphinx-relay/config/app.json.tmp /home/sphinxrelay/sphinx-relay/config/app.json
  # prepare production configs (loaded by nodejs app)
  cp /home/sphinxrelay/sphinx-relay/config/app.json /home/sphinxrelay/sphinx-relay/dist/config/app.json
  cp /home/sphinxrelay/sphinx-relay/config/config.json /home/sphinxrelay/sphinx-relay/dist/config/config.json
  echo "# ok - copied fresh config.json & app.json into dist directory"
  exit 0
fi