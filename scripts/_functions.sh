#!/bin/bash

# sourceConf <config-file>
# Parse a KEY=value config file as DATA - never execute it as shell code.
# Fails closed: aborts with a non-zero exit and an error on stderr naming the
# file and line number if any line is malformed or contains characters that
# have no legitimate use in this config (and could be used for code execution
# if the file was sourced as shell code).
function sourceConf() {
  local confFile="$1"
  local line key value lineNr=0
  if [ ! -f "$confFile" ]; then
    echo "# sourceConf ERROR: config file not found: $confFile" >&2
    exit 1
  fi
  # read from the file directly (not a pipe) so variables stay in this shell
  while IFS= read -r line || [ -n "$line" ]; do
    lineNr=$((lineNr + 1))
    # allow blank lines and comments
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    # valid lines must be KEY=value
    if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      echo "# sourceConf ERROR: malformed line $lineNr in $confFile" >&2
      exit 1
    fi
    key="${line%%=*}"
    value="${line#*=}"
    # reject characters with no legitimate use in this config that would be
    # dangerous if the file was ever executed as shell code
    # shellcheck disable=SC2016 # the '$(' etc. below are intentional literals
    if [[ "$value" == *'`'* || "$value" == *'$('* || "$value" == *';'* || \
          "$value" == *'|'* || "$value" == *'&'* || \
          "$value" == *'<'* || "$value" == *'>'* ]]; then
      echo "# sourceConf ERROR: forbidden character in the value on line $lineNr in $confFile" >&2
      exit 1
    fi
    # strip one pair of matching surrounding quotes (as the shell would when sourcing)
    if [[ "$value" =~ ^\'(.*)\'$ ]] || [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    # assign as data (global scope) - never eval
    declare -g "$key=$value"
  done < "$confFile"
}

sourceConf /home/joinmarket/joinin.conf

# versions
currentJBcommit=$(cd /home/joinmarket/joininbox; git describe --tags)
currentJBtag=$(cd /home/joinmarket/joininbox; git tag | sort -V | tail -1)
currentJMNGversion=$(/home/joinmarketng/venv/bin/python -c \
  'from importlib.metadata import version; print(version("jmcore"))' 2>/dev/null || printf "not installed")
currentBTCversion=$(bitcoind --version | grep version)

# paths
walletPath="/home/joinmarket/.joinmarket/wallets/"
JMcfgPath="/home/joinmarket/.joinmarket/joinmarket.cfg"
joininConfPath="/home/joinmarket/joinin.conf"

## dialog fixes
# fallback for unknown terminal types (e.g., xterm-ghostty)
if ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi
# fix dialog box drawing characters
export NCURSES_NO_UTF8_ACS=1

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
  # Create an unpredictable, user-only credential file in RAM.
  # get password
  local data
  data=$(mktemp /dev/shm/joininbox-dialog.XXXXXX) || return 1
  walletPasswordFile=$(mktemp /dev/shm/joininbox-wallet-password.XXXXXX) || {
    rm -f -- "$data"
    return 1
  }
  chmod 600 -- "$data" "$walletPasswordFile"
  # keep parity with the chooseWallet EXIT trap so the $wallet temp file is
  # still cleaned up on shell exit after passwordToFile replaces the trap
  trap 'rm -f -- "$data" "$walletPasswordFile" "$wallet"' EXIT
  dialog --clear \
   --backtitle "Enter password" \
   --title "Enter password" \
   --insecure \
   --passwordbox "Type or paste the wallet decryption password" 8 52 2> "$data"
  # make decision
  pressed=$?
  case $pressed in
    0)
      tee "$walletPasswordFile" 1>/dev/null < "$data"
      rm -f -- "$data"
      ;;
    1)
      rm -f -- "$data" "$wallet" "$walletPasswordFile"
      echo "# Cancelled"
      exit 1
      ;;
    255)
      [ -s "$data" ] &&  cat "$data" || echo "# ESC pressed."
      rm -f -- "$data" "$wallet" "$walletPasswordFile"
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

# validateServiceArgs <script> <walletInput>
# Validates a systemd service name and wallet input for start.service.sh.
# Prints the canonical wallet path on stdout when valid.
# Returns 1 (message on stderr) when the input is rejected.
# Used to reject bad input BEFORE any credential file (the wallet password temp file) is created.
function validateServiceArgs() {
  local script="$1"
  local walletInput="$2"

  if [ "$script" != "yg-privacyenhanced" ]; then
    echo "# Refusing unsupported service: $script" >&2
    return 1
  fi

  if [ -L "$walletInput" ]; then
    echo "# Refusing a symlink as wallet input" >&2
    return 1
  fi
  local wallet
  wallet=$(readlink -f -- "$walletInput") || return 1
  local walletDirectory
  walletDirectory=$(readlink -f -- "$walletPath") || return 1
  local walletFileName
  walletFileName=$(basename -- "$wallet")
  case "$walletFileName" in
    ''|*[!A-Za-z0-9._-]*)
      echo "# Refusing unsafe wallet filename" >&2
      return 1
      ;;
  esac
  if [ ! -f "$wallet" ] || \
    [ "$(dirname -- "$wallet")" != "$walletDirectory" ]; then
    echo "# Wallet must be a regular file directly inside $walletDirectory" >&2
    return 1
  fi

  echo "$wallet"
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
  newest_log=$(ls -td /home/joinmarket/.joinmarket/logs/*J5* 2>/dev/null | head -n 1)
  if [ -n "$newest_log" ] && [ -f "$newest_log" ]; then
    name=$(grep NickServ "$newest_log" 2>/dev/null | tail -1 | awk '{print $9}')
    if [ ${#name} -eq 0 ]; then
      name="no_Nick_see_LOGS"
    fi
  else
    name="waiting__to__run"
  fi
  echo "$name"
}

# copyJoininboxScripts
function copyJoininboxScripts() {
  echo "# Copying the scripts in place"
  sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/*.* /home/joinmarket/
  sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
  sudo -u joinmarket chmod +x /home/joinmarket/*.sh
  sudo install -d -m 755 -o root -g root /usr/local/libexec/joininbox
  sudo install -m 755 -o root -g root \
    /home/joinmarket/joininbox/scripts/install.joinmarket-ng.sh \
    /usr/local/libexec/joininbox/install.joinmarket-ng.sh
  sudo install -m 755 -o root -g root \
    /home/joinmarket/joininbox/scripts/set.joinmarket-ng-config.py \
    /usr/local/libexec/joininbox/set.joinmarket-ng-config.py
  if [ $runningEnv = "standalone" ];then
    sudo -u joinmarket cp -r /home/joinmarket/joininbox/scripts/standalone /home/joinmarket/
    sudo -u joinmarket chmod +x /home/joinmarket/standalone/*.sh
  fi
}

# Accept only a decimal GitHub pull-request number. This is checked before any
# repository removal and before constructing the fetch refspec.
function validatePRNumber() {
  case "$1" in
    ''|*[!0-9]*)
      echo "# Invalid pull-request number: $1" >&2
      return 1
      ;;
  esac
}

# updateJoininBox <reset|commit|pr[PRnumber]>
function verifyJoininBoxRef() {
  local ref="$1"
  local kind="$2"
  local signer keyUrl fingerprint signature

  if [ "$kind" = "tag" ]; then
    signer="openoms"
    keyUrl="https://github.com/openoms.gpg"
    fingerprint="13C688DB5B9C745DE4D2E4545BFB77609B081B65"
    /home/joinmarket/verify.git.sh "$signer" "$keyUrl" "$fingerprint" "$ref"
    return
  fi

  signature=$(git log -1 --show-signature --format=oneline "$ref" 2>&1)
  if echo "$signature" | grep -q '13C688DB5B9C745DE4D2E4545BFB77609B081B65'; then
    signer="openoms"
    keyUrl="https://github.com/openoms.gpg"
    fingerprint="13C688DB5B9C745DE4D2E4545BFB77609B081B65"
  elif echo "$signature" | grep -q '44912E1E03005B31'; then
    signer="joinmarket-ng"
    keyUrl="https://raw.githubusercontent.com/joinmarket-ng/joinmarket-ng/0c3716b53c132bd46fc92d240beebe7158a06e16/signatures/pubkeys/1C53A412D11EF3051704419C44912E1E03005B31.asc"
    fingerprint="1C53A412D11EF3051704419C44912E1E03005B31"
  elif echo "$signature" | grep -q 'B5690EEEBB952194'; then
    signer="web-flow"
    keyUrl="https://github.com/web-flow.gpg"
    fingerprint="968479A1AFF927E37D1A566BB5690EEEBB952194"
  else
    echo "# Refusing an update without a recognized signing key" >&2
    return 1
  fi
  /home/joinmarket/verify.git.sh "$signer" "$keyUrl" "$fingerprint"
}

function updateJoininBox() {
  if [ "$1" = "pr" ]; then
    validatePRNumber "$2" || return 1
  fi
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
    echo ""
    echo "##########################################################" >&2
    echo "# WARNING: installing UNVERIFIED pull-request code" >&2
    echo "# https://github.com/openoms/joininbox/pull/$PRnumber" >&2
    echo "# This code is NOT signed by a maintainer and will run" >&2
    echo "# with elevated privileges on this system." >&2
    echo "##########################################################" >&2
    echo ""
    sudo -u joinmarket git fetch origin pull/$PRnumber/head:pr$PRnumber || return 1
    sudo -u joinmarket git checkout pr$PRnumber || return 1
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
  if [ "$1" = "pr" ]; then
    echo "# Skipping signature verification for unverified PR code"
  elif [ "$1" = "commit" ]; then
    verifyJoininBoxRef HEAD commit || return 1
  else
    verifyJoininBoxRef "$TAG" tag || return 1
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
    sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = watch-only-descriptor-wallet/g" $JMcfgPath
    echo "# using the bitcoind watch-only-descriptor-wallet"
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
  local torKeyFingerprint="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
  local torSigningFingerprint="2265EB4CB2BF88D900AE8D1B74A941BA219EC810"
  local torKeyFile
  local torKeyFingerprints
  torKeyFile=$(mktemp)
  wget --prefer-family=ipv4 -qO "${torKeyFile}" \
    "https://deb.torproject.org/torproject.org/${torKeyFingerprint}.asc"
  torKeyFingerprints=$(gpg --show-keys --with-colons "${torKeyFile}" | awk -F: '/^fpr:/ {print $10}')
  if ! grep -qx "${torKeyFingerprint}" <<<"${torKeyFingerprints}" ||
    ! grep -qx "${torSigningFingerprint}" <<<"${torKeyFingerprints}"; then
    rm -f "${torKeyFile}"
    echo "# Unexpected deb.torproject.org signing key"
    return 1
  fi
  sudo gpg --batch --yes --dearmor \
    --output /usr/share/keyrings/deb.torproject.org-keyring.gpg "${torKeyFile}"
  rm -f "${torKeyFile}"
  sudo chmod 644 /usr/share/keyrings/deb.torproject.org-keyring.gpg

  echo "# Adding tor-nightly-main to /etc/apt/sources.list.d/tor.list"
  arch=$(dpkg --print-architecture)
  distro=$(lsb_release -sc)
  echo "\
deb [arch=${arch} signed-by=/usr/share/keyrings/deb.torproject.org-keyring.gpg] https://deb.torproject.org/torproject.org tor-nightly-main-$distro main
deb-src [arch=${arch} signed-by=/usr/share/keyrings/deb.torproject.org-keyring.gpg] https://deb.torproject.org/torproject.org tor-nightly-main-$distro main" \
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
