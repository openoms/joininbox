#!/bin/bash

source /home/joinmarket/joinin.conf

# versions
currentJBcommit=$(cd /home/joinmarket/joininbox; git describe --tags)
currentJBtag=$(cd /home/joinmarket/joininbox; git tag | sort -V | tail -1)
currentJMversion=$(cd /home/joinmarket/joinmarket-clientserver 2>/dev/null; \
git describe --tags 2>/dev/null)
currentBTCversion=$(bitcoind --version | grep version)

# paths
walletPath="/home/joinmarket/.joinmarket/wallets/"
JMcfgPath="/home/joinmarket/.joinmarket/joinmarket.cfg"
joininConfPath="/home/joinmarket/joinin.conf"

# functions
source /home/joinmarket/_functions.menu.sh
source /home/joinmarket/_functions.bitcoincore.sh
if [ "${runningEnv}" = standalone ]; then
  source /home/joinmarket/standalone/_functions.standalone.sh
fi

function activateJMvenv() {
  . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate || exit 1
}

function openMenuIfCancelled() {
  pressed=$1
  case $pressed in
    1)
      clear
      echo "# Cancelled"
      sleep 1
      exit 1;;
    255)
      clear
      echo "# ESC pressed"
      sleep 1
      exit 1;;
  esac
}

function errorOnInstall() {
  if [ "$1" -gt 0 ]; then
    DIALOGRC=/home/joinmarket/.dialogrc.onerror dialog --title "Error during install" \
      --msgbox "\nPlease search or report at:\nhttps://github.com/openoms/joininbox/issues\nwith the logs above" 8 56
    exit 1
  fi
}

function waitKeyOnExit1() {
  if [ "$1" -gt 0 ]; then
      echo "# Press ENTER to return to the menu."
      read key
  fi
}

function passwordToFile() {
  # write password into a file (to be shredded)
  # get password
  trap 'rm -f "$data"' EXIT
  data=$(mktemp -p /dev/shm/)
  dialog --clear \
   --backtitle "Enter password" \
   --title "Enter password" \
   --insecure \
   --passwordbox "Type or paste the wallet decryption password" 8 52 2> "$data"
  # make decision
  pressed=$?
  case $pressed in
    0)
      touch /dev/shm/.pw
      chmod 600 /dev/shm/.pw
      tee /dev/shm/.pw 1>/dev/null < "$data"
      shred "$data"
      ;;
    1)
      shred "$data"
      shred "$wallet"
      shred -uvz /dev/shm/.pw
      echo "# Cancelled"
      exit 1
      ;;
    255)
      shred "$data"
      shred "$wallet"
      shred -uvz /dev/shm/.pw
      [ -s "$data" ] &&  cat "$data" || echo "# ESC pressed."
      exit 1
      ;;
  esac
}

# chooseWallet <noLockFileCheck>
function chooseWallet() {
  trap 'rm -f "$wallet"' EXIT
  wallet=$(mktemp -p /dev/shm/)
  if [ "$defaultWallet" = "off" ]; then
    dialog --clear \
     --backtitle "Choose a wallet by typing the full name of the file" \
     --title "Choose a wallet by typing the full name of the file" \
     --fselect "$walletPath" 20 60 2> "$wallet"
    openMenuIfCancelled $?
  else
    echo "$defaultWallet" > "$wallet"
  fi
  if [ ! -f $(cat $wallet) ];then
    clear
    echo
    echo "# Error: $(cat $wallet) file not found"
    echo "# Make sure to type the full filename of the wallet."
    echo "# eg.: wallet.jmdat"
    echo
    exit 1
  else
    echo "# OK - the $(cat $wallet) file is present"
  fi

  walletFileName=$(cat $wallet | cut -d/ -f6)
  if [ $# -eq 0 ] || [ $1 != "noLockFileCheck" ];then
    if [ -f /home/joinmarket/.joinmarket/wallets/.${walletFileName}.lock ];then
      echo
      echo "# A wallet lockfile is found: /home/joinmarket/.joinmarket/wallets/.${walletFileName}.lock"
      echo
      echo "# Press ENTER to make sure the Yield Generator is stopped and the lockfile is deleted (or use CTRL+C to abort)"
      echo
      read key
      stopYG $(cat $wallet)
    else
      echo "# OK - no .${walletFileName}.lock file is present"
    fi
  fi
}

# stopYG <wallet>
function stopYG() {
  if [ $# -eq 1 ]; then
    local stopWallet=$1
  else
    local stopWallet=$YGwallet
  fi
  # stop the background process (equivalent to CTRL+C)
  # use the YGwallet from joinin.conf
  pkill -sigint -f "python yg-privacyenhanced.py $stopWallet --wallet-password-stdin"
  # pgrep python | xargs kill -sigint
  # remove the service
  sudo systemctl stop yg-privacyenhanced
  sudo systemctl disable yg-privacyenhanced
  # check for failed services
  # sudo systemctl list-units --type=service
  sudo systemctl reset-failed
  echo "# Stopped the Yield Generator background service"
  # make sure the lock file is deleted
  local walletFileName=$(echo $stopWallet | cut -d/ -f6)
  if rm /home/joinmarket/.joinmarket/wallets/.${walletFileName}.lock 2>/dev/null; then
    echo "# The file .$walletFileName.lock is removed"
  else
    echo "# The file .$walletFileName.lock is not present"
  fi
}

function YGnickname() {
  # Retrieves nickname from the latest NickServ message in the newest logfile
  if ls -td /home/joinmarket/.joinmarket/logs/* 1>&2>/dev/null ; then
    newest_log=$(ls -td /home/joinmarket/.joinmarket/logs/* | grep J5 | head -n 1)
    name=$(grep NickServ $newest_log | tail -1 | awk '{print $9}')
    if [ ${#name} -eq 0 ];then
      name="no_Nick_see_LOGS"
    fi
  else
    name="waiting__to__run"
  fi
  echo $name
}

# copyJoininboxScripts
function copyJoininboxScripts() {
  echo "# Copying the scripts in place"
  sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/*.* /home/joinmarket/
  sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
  sudo -u joinmarket chmod +x /home/joinmarket/*.sh
  if [ $runningEnv = "standalone" ];then
    sudo -u joinmarket cp -r /home/joinmarket/joininbox/scripts/standalone /home/joinmarket/
    sudo -u joinmarket chmod +x /home/joinmarket/standalone/*.sh
  fi
}

# updateJoininBox <reset|commit|pr[PRnumber]>
function updateJoininBox() {
  cd /home/joinmarket || exit 1
  if [ "$1" = "reset" ] ||  [ "$1" = "pr" ];then
    echo "# Removing the joininbox source code"
    sudo rm -rf /home/joinmarket/joininbox
    echo "# Downloading the latest joininbox source code"
  fi
  # clone repo in case it is not present
  sudo -u joinmarket git clone https://github.com/openoms/joininbox.git \
  /home/joinmarket/joininbox 2>/dev/null
  echo "# Checking the updates in https://github.com/openoms/joininbox"
  # based on https://github.com/apotdevin/thunderhub/blob/master/scripts/updateToLatest.sh
  cd /home/joinmarket/joininbox || exit 1
  # fetch latest master
  sudo -u joinmarket git fetch
  echo "# Pulling latest changes..."
  sudo -u joinmarket git pull -p
  if [ "$1" = "commit" ]; then
    TAG=$(git describe --tags)
    echo "# Updating to the latest commit in the default branch"
  elif [ "$1" = "pr" ]; then
    PRnumber=$2
    echo "# Using the PR:"
    echo "# https://github.com/JoinMarket-Org/joinmarket-clientserver/release/tag/$PRnumber"
    sudo -u joinmarket git fetch origin pull/$PRnumber/head:pr$PRnumber
    sudo -u joinmarket git checkout pr$PRnumber
    TAG=$(git describe --tags)
  else
    TAG=$(git tag | sort -V | tail -1)
    # unset $1
    set --
    UPSTREAM=${1:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    if [ $LOCAL = $REMOTE ]; then
      echo "# You are up-to-date on version" $TAG
    fi
    sudo -u joinmarket git reset --hard $TAG
  fi
  echo "# Current version: $TAG"
  copyJoininboxScripts
}

function generateJMconfig() {
  if [ ! -f "$JMcfgPath" ] ; then
    echo "# Generating joinmarket.cfg with default settings"
    echo
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
    cd /home/joinmarket/joinmarket-clientserver/scripts/ || exit 1
    python wallet-tool.py generate --datadir=/home/joinmarket/.joinmarket
  else
    echo "# The joinmarket.cfg is present"
    echo
  fi

  # set strict permission to joinmarket.cfg
  sudo chmod 600 $JMcfgPath || exit 1

  if [ "${network}" = "signet" ]; then

    setJMconfigToSignet

  elif [ $runningEnv = "raspiblitz" ]; then
    echo
    echo "## editing the joinmarket.cfg with the local bitcoin RPC settings."
    if [ -f "/mnt/hdd/bitcoin/bitcoin.conf" ]; then
      RPCUSER=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
      sed -i "s/^rpc_user =.*/rpc_user = $RPCUSER/g" $JMcfgPath
      echo "# rpc_user = $RPCUSER"
      PASSWORD_B=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
      sed -i "s/^rpc_password =.*/rpc_password = $PASSWORD_B/g" $JMcfgPath
      echo "# rpc_password = $PASSWORD_B"
      RPCPORT=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep main.rpcport | cut -c 14-)
    else
      RPCUSER=$(sudo cat /mnt/hdd/app-data/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
      sed -i "s/^rpc_user =.*/rpc_user = $RPCUSER/g" $JMcfgPath
      echo "# rpc_user = $RPCUSER"
      PASSWORD_B=$(sudo cat /mnt/hdd/app-data/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
      sed -i "s/^rpc_password =.*/rpc_password = $PASSWORD_B/g" $JMcfgPath
      echo "# rpc_password = $PASSWORD_B"
      RPCPORT=$(sudo cat /mnt/hdd/app-data/bitcoin/bitcoin.conf | grep main.rpcport | cut -c 14-)
    fi
    if [ ${#RPCPORT} -eq 0 ]; then
      RPCPORT=8332
    fi
    sed -i "s/^rpc_port =.*/rpc_port = $RPCPORT/g" $JMcfgPath
    echo  "# rpc_port = $RPCPORT"
    sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/g" $JMcfgPath
    echo "# using the bitcoind wallet: wallet.dat"
    # set joinin.conf value
    /home/joinmarket/set.value.sh set network mainnet ${joininConfPath}
  fi
 }

#backupJMconf
function backupJMconf() {
  if [ -f "$JMcfgPath" ] ; then
    now=$(date +"%Y_%m_%d_%H%M%S")
    echo "# Moving the joinmarket.cfg to the filename joinmarket.cfg.backup$now"
    mv $JMcfgPath \
    $JMcfgPath.backup$now
    echo
  else
    echo "# The joinmarket.cfg is not present"
    echo
  fi
}

# updateTor
function updateTor() {
  # as in https://2019.www.torproject.org/docs/debian#source
  # https://github.com/rootzoll/raspiblitz/blob/82e0d6c3714ce1b2878780c4bdef72a6417f71c7/home.admin/config.scripts/internet.tor.sh#L493
  echo "# Adding tor-nightly-main to /etc/apt/sources.list.d/tor.list"
  arch=$(dpkg --print-architecture)
  distro=$(lsb_release -sc)
  echo "\
deb [arch=${arch}] https://deb.torproject.org/torproject.org tor-nightly-main-$distro main
deb-src [arch=${arch}] https://deb.torproject.org/torproject.org tor-nightly-main-$distro main" \
  | sudo tee /etc/apt/sources.list.d/tor.list
  echo "# Running apt-get update"
  sudo apt-get update
  if [ ${arch} = "amd64" ] || [ ${arch} = "arm64" ]; then
    echo "# CPU is ${arch} - updating to the latest alpha binary"
    sudo apt-get install -y tor
    echo "# Restarting the tor.service "
    sudo systemctl restart tor
  else
    echo "# Install the dependencies for building from source"
    sudo apt-get install -y build-essential fakeroot devscripts
    sudo apt-get build-dep -y tor deb.torproject.org-keyring
    rm -rf $HOME//download/debian-packages
    mkdir -p $HOME/download/debian-packages
    cd $HOME/download/debian-packages || exit 1
    echo "# Building Tor from the source code ..."
    apt-get source tor
    cd tor-* || exit 1
    debuild -rfakeroot -uc -us
    cd .. || exit 1
    echo "# Stopping the tor.service before updating"
    sudo systemctl stop tor
    echo "# Update ..."
    sudo dpkg -i tor_*.deb
    echo "# Starting the tor.service "
    sudo systemctl start tor
    echo "# Installed $(tor --version)"
  fi
}

# torTest - unused, moved from the build script to not break github actions
function torTest() {
  tries=0
  while [ "${torTest}" != "Congratulations. This browser is configured to use Tor." ]
  do
    echo "# waiting another 10 seconds for Tor"
    echo "# press CTRL + C to abort"
    sleep 10
    tries=$((tries+1))
    if [ $tries = 100 ]; then
      echo "# FAIL - Tor was not set up successfully"
      exit 1
    fi
    torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
    https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
  done
  echo
  echo "# $torTest"
  echo
  echo "# Tor has been tested successfully"
}

# https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md#co-signing-a-psbt
function signPSBT() {
  chooseWallet
  clear
  echo
  echo "# Notes on usage:"
  echo "https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md#co-signing-a-psbt"
  echo
  echo "# Once signed the transaction will be presented ready for broadcast."
  echo "# DO NOT BROADCAST here for lightning channel opens"
  echo "# Paste the PSBT to be signed and press ENTER:"
  read PSBT
  /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)" signpsbt nomixdepth nomakercount "$PSBT"
  echo
  echo "Press ENTER to return to the menu..."
  read key
}

function confirmation() {
  local text=$1
  local yesButtonText=$2
  local noButtonText=$3
  local defaultno=$4
  local height=$5
  local width=$6

  if [ $defaultno ]; then
    dialog \
    --backtitle "Confirmation" \
    --title "Confirmation" \
    --yes-button "$yesButtonText" \
    --no-button "$noButtonText" \
    --defaultno \
    --yesno \
    "
  $text
  " "$height" "$width"
  else
    dialog \
    --backtitle "Confirmation" \
    --title "Confirmation" \
    --yes-button "$yesButtonText" \
    --no-button "$noButtonText" \
    --yesno \
    "
  $text
  " "$height" "$width"
  fi
  answer=$?
  return $answer
}