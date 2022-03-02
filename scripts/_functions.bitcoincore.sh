#!/bin/bash

# paths
walletPath="/home/joinmarket/.joinmarket/wallets/"
JMcfgPath="/home/joinmarket/.joinmarket/joinmarket.cfg"
joininConfPath="/home/joinmarket/joinin.conf"

# downloadBitcoinCore
function downloadBitcoinCore() {
  # set version
  # https://bitcoincore.org/en/download/
  bitcoinVersion="22.0"

  # https://github.com/laanwj
  laanwjPGP="71A3 B167 3540 5025 D447 E8F2 7481 0B01 2346 C9A6"

  echo
  echo "# *** PREPARING BITCOIN ***"
  # prepare directories
  sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
  cd /home/joinmarket/download || exit 1

  # receive signer key
  if ! gpg --keyserver hkp://keyserver.ubuntu.com --recv-key "71A3 B167 3540 5025 D447 E8F2 7481 0B01 2346 C9A6"
  then
    echo "# !!! FAIL !!! Couldn't download Wladimir J. van der Laan's PGP pubkey"
    exit 1
  fi

  # download signed binary sha256 hash sum file
  if [ ! -f SHA256SUMS ];then
    sudo -u joinmarket wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS
  fi
  # download signed binary sha256 hash sum file and check
  if [ ! -f SHA256SUMS.asc ];then
    sudo -u joinmarket wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc
  fi
  verifyResult=$(gpg --verify SHA256SUMS.asc 2>&1)
  goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
  echo "goodSignature(${goodSignature})"
  correctKey=$(echo ${verifyResult} | grep "${laanwjPGP}" -c)
  echo "correctKey(${correctKey})"
  if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
    echo
    echo "# !!! BUILD FAILED --> the PGP verification failed / signature(${goodSignature}) verify(${correctKey})"
    echo "# Removing the conflicting files"
    echo "# This is normal after an update - try to choose the option / run the script again."
    sudo rm -f SHA256SUMS
    sudo rm -f SHA256SUMS.asc
    exit 1
  else
    echo
    echo "****************************************"
    echo "OK --> BITCOIN MANIFEST IS CORRECT"
    echo "****************************************"
    echo
  fi

  # detect CPU architecture & fitting download link
  if [ $(uname -m | grep -c 'arm') -eq 1 ] ; then
    bitcoinOSversion="arm-linux-gnueabihf"
  fi
  if [ $(uname -m | grep -c 'aarch64') -eq 1 ] ; then
    bitcoinOSversion="aarch64-linux-gnu"
  fi
  if [ $(uname -m | grep -c 'x86_64') -eq 1 ] ; then
    bitcoinOSversion="x86_64-linux-gnu"
  fi

  echo
  echo "*** BITCOIN CORE v${bitcoinVersion} for ${bitcoinOSversion} ***"

  # download resources
  binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
  if [ ! -f "./${binaryName}" ]; then
     sudo -u joinmarket wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName}
  fi
  if [ ! -f "./${binaryName}" ]; then
    echo "!!! FAIL !!! Could not download the BITCOIN BINARY"
    exit 1
  else
    # check binary checksum test
    echo "- checksum test"
    # get the sha256 value for the corresponding platform from signed hash sum file
    bitcoinSHA256=$(grep -i "${binaryName}" SHA256SUMS | cut -d " " -f1)
    binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
    echo "Valid SHA256 checksum should be: ${bitcoinSHA256}"
    echo "Downloaded binary SHA256 checksum: ${binaryChecksum}"
    if [ "${binaryChecksum}" != "${bitcoinSHA256}" ]; then
      echo "!!! FAIL !!! Downloaded BITCOIN BINARY not matching SHA256 checksum: ${bitcoinSHA256}"
      rm -v ./${binaryName}
      exit 1
    else
      echo
      echo "********************************************"
      echo "OK --> VERIFIED BITCOIN CORE BINARY CHECKSUM"
      echo "********************************************"
      echo
      sleep 10
      echo
    fi
    echo
    echo "# Extracting to /home/joinmarket/download/bitcoin-${bitcoinVersion}"
    sudo -u joinmarket tar -xvf ${binaryName}
    echo
  fi
}

function installBitcoinCore() {
  downloadBitcoinCore

  echo "# Installing Bitcoin Core v${bitcoinVersion}"
  sudo -u joinmarket mkdir -p /home/joinmarket/bitcoin
  cd /home/joinmarket/download/bitcoin-${bitcoinVersion}/bin/ || exit 1
  sudo install -m 0755 -o root -g root -t /home/joinmarket/bitcoin ./*

  if [ "$(grep -c "/home/joinmarket/bitcoin" < /home/joinmarket/.profile)" -eq 0 ];then
    echo "# Add /home/joinmarket/bitcoin to the local PATH"
    echo "PATH=/home/joinmarket/bitcoin:$PATH" | sudo tee -a /home/joinmarket/.profile
  fi
  installed=$(/home/joinmarket/bitcoin/bitcoind --version | grep -c "Bitcoin Core version")
  if [ ${installed} -lt 1 ]; then
    echo
    echo "!!! BUILD FAILED --> Was not able to install Bitcoin Core"
    exit 1
  fi

  # bitcoin.conf
  if [ ! -f /home/joinmarket/.bitcoin/bitcoin.conf ];then
    mkdir -p /home/joinmarket/.bitcoin
    randomRPCpass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
    cat > /home/joinmarket/.bitcoin/bitcoin.conf <<EOF
# bitcoind configuration for signet

# Connection settings
rpcuser=joinmarket
rpcpassword=$randomRPCpass

onlynet=onion
proxy=127.0.0.1:9050
EOF
  else
    echo "# /home/joinmarket/.bitcoin/bitcoin.conf is present"
  fi
}

function removeSignetdService() {
  if [ -f "/etc/systemd/system/signetd.service" ];then
    sudo systemctl stop signetd
    sudo systemctl disable signetd
    echo "# Bitcoin Core on signet service is stopped and disabled"
    echo
  fi
}

function installSignet() {
  # fix permissions
  sudo chown -R joinmarket:joinmarket /home/joinmarket/.bitcoin/
  removeSignetdService

  # /etc/systemd/system/signetd.service
  echo "
[Unit]
Description=Bitcoin daemon on signet

[Service]
User=joinmarket
Group=joinmarket
Type=forking
PIDFile=/home/joinmarket/bitcoin/bitcoind.pid
ExecStart=/home/joinmarket/bitcoin/bitcoind -signet -daemon \
 -datadir=/home/joinmarket/.bitcoin \
 -conf=/home/joinmarket/.bitcoin/bitcoin.conf \
 -pid=/home/joinmarket/bitcoin/bitcoind.pid
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/signetd.service
  sudo systemctl enable signetd
  echo "# OK - the bitcoin daemon on signet service is now enabled"

  # add to path
  if ! sudo grep -Eq "/home/joinmarket/bitcoin/" < /etc/profile ;then
    echo "PATH=\$PATH:/home/joinmarket/bitcoin/" | sudo tee -a /etc/profile
  fi

  # add aliases
  if [ $(alias | grep -c signet) -eq 0 ]; then
    sudo bash -c "echo 'alias signet-cli=\"/home/joinmarket/bitcoin/bitcoin-cli -signet\"' >> /home/joinmarket/_aliases.sh"
    sudo bash -c "echo 'alias signetd=\"/home/joinmarket/bitcoin/bitcoind -signet\"' >> /home/joinmarket/_aliases.sh"
  fi

  sudo systemctl start signetd

  echo
  echo "# Installed $(/home/joinmarket/bitcoin/bitcoind --version | grep version)"
  echo
  echo "# Monitor the signet bitcoind with: tail -f ~/.bitcoin/signet/debug.log"
  echo

}

setJMconfigToSignet() {
  echo "# editing the joinmarket.cfg"
  # rpc_user
  RPCUSERSIGNET=$(sudo cat /home/joinmarket/.bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
  sed -i "s/^rpc_user =.*/rpc_user = $RPCUSERSIGNET/g" $JMcfgPath
  # rpc_password
  RPCPWSIGNET=$(sudo cat /home/joinmarket/.bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
  sed -i "s/^rpc_password =.*/rpc_password = $RPCPWSIGNET/g" $JMcfgPath
  # rpc_wallet_file
  sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/g" $JMcfgPath
  echo "# using the bitcoind wallet: wallet.dat"
  # rpc_host
  sed -i "s/^rpc_host =.*/rpc_host = 127.0.0.1/g" $JMcfgPath
  # rpc_port
  sed -i "s/^rpc_port =.*/rpc_port = 38332/g" $JMcfgPath
  # network
  sed -i "s/^network =.*/network = signet/g" $JMcfgPath
  # minimum_makers
  sed -i "s/^minimum_makers =.*/minimum_makers = 1/g" $JMcfgPath
}

function showBitcoinLogs() {
  if [ $# -eq 0 ];then
    lines=""
    echo "# Show the default number of lines"
  else
    lines="-n $1"
    echo "# Show $lines number of lines"
  fi
  if [ $network = mainnet ];then
    logFilePath="/home/bitcoin/.bitcoin/debug.log"
  elif [ $network = signet ];then
    logFilePath="/home/joinmarket/.bitcoin/signet/debug.log"
  fi
  dialog \
    --title "Monitoring the $network logs"  \
    --msgbox "
Will tail the bitcoin $network logfile from:

$logFilePath

Press CTRL+C to exit and type 'menu' for the GUI." 10 54
  sudo tail -f $lines $logFilePath
}

# getRPC - reads the RPC settings from the joinmarket.cfg
function getRPC {
  echo "# Reading the bitcoind RPC settings from the joinmarket.cfg"
  rpc_user="$(awk '/^rpc_user / {print $3}' < $JMcfgPath)"
  rpc_pass="$(awk '/^rpc_password / {print $3}' < $JMcfgPath)"
  rpc_host="$(awk '/^rpc_host / {print $3}' < $JMcfgPath)"
  rpc_port="$(awk '/^rpc_port / {print $3}' < $JMcfgPath)"
  rpc_wallet="$(awk '/^rpc_wallet_file / {print $3}' < $JMcfgPath)"
  if [ ${#1} -gt 0 ]&&[ $1 = print ];then
    echo "$rpc_user $rpc_pass $rpc_host $rpc_port $rpc_wallet"
  fi
}

# checkRPCwallet <wallet>
function checkRPCwallet {
  getRPC
  if [ $# -eq 0 ];then
    rpc_wallet=$rpc_wallet
  else
    rpc_wallet=$1
  fi
  echo "# Making sure the set $rpc_wallet wallet is present in bitcoind"
  trap 'rm -f "$connectionOutput"' EXIT
  connectionOutput=$(mktemp -p /dev/shm/)
  walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
  if [ $walletFound -eq 0 ]; then
    echo "# Setting a watch only wallet for the remote Bitcoin Core named $rpc_wallet"
    customRPC "# Create the bitcoind wallet" "createwallet" "$rpc_wallet"
    echo
    walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
    if [ $walletFound -eq 0 ]; then
      echo "# Making sure $rpc_wallet wallet is loaded in bitcoind"
      echo
      customRPC "# Load wallet in bitcoind" "loadwallet" "$rpc_wallet"
      walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
    fi
    echo
  fi
  echo "# The wallet: $rpc_wallet is present and loaded in the connected bitcoind"
}

# customRPC - sends a custom RPC command
# $1=id $2=method $3=string params $4=print
function customRPC {
  getRPC
  if [ ${#4} -eq 0 ];then
    print="no"
  else
    print=$4
  fi
if [ $print = print ];then
  echo print
fi
  tor=""
  if [ $(echo $rpc_host | grep -c .onion) -gt 0 ]; then
    tor="torsocks"
    echo "# Connecting over Tor..."
    echo
  fi
  is_int () { test "$@" -eq "$@" 2> /dev/null; }
  if is_int "$3" ||[ ${#3} -eq 0 ]; then
    if [ $print = print ];then
      echo "# Using the RPC command:"
      echo "$tor curl -sS --data-binary\
 '{\"jsonrpc\": \"1.0\", \"id\":\"$1\", \"method\": \"$2\", \"params\": [$3] }'\
 http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet"
      echo
    fi
    $tor curl -sS --data-binary \
    '{"jsonrpc": "1.0", "id":"'"$1"'", "method": "'"$2"'", "params": ['"$3"'] }' \
    http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet  | jq .
  else
    if [ $print = print ];then
      echo "# Using the RPC command:"
      echo "$tor curl -sS --data-binary\
 '{\"jsonrpc\": \"1.0\", \"id\":\"$1\", \"method\": \"$2\", \"params\": [\"$3\"] }'\
 http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet"
      echo
    fi
    $tor curl -sS --data-binary \
    '{"jsonrpc": "1.0", "id":"'"$1"'", "method": "'"$2"'", "params": ["'"$3"'"] }' \
    http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet | jq .
  fi
}

function connectLocalNode() {
  if [ ${#1} -gt 0 ];then
    network=$1
  fi
  echo "# Setting connection to the local Bitcoin node on $network"
  rpc_host="127.0.0.1"
  if [ $network = mainnet ];then
    rpc_port="8332"
  elif [ $network = signet ];then
    rpc_port="38332"
  elif [ $network = testnet ];then
    rpc_port="18332"
  fi
  rpc_wallet="wallet.dat"
  if [ $runningEnv = raspiblitz ];then
    rpc_user=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
    rpc_pass=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf|grep rpcpassword|cut -c 13-)
  elif [ $runningEnv = mynode ];then
    rpc_user=mynode
    rpc_pass=$(sudo cat /mnt/hdd/mynode/settings/.btcrpcpw)
  elif [ $runningEnv = standalone ];then
    rpc_user=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf|grep rpcuser|cut -c 9-)
    rpc_pass=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf|grep rpcpassword|cut -c 13-)
  fi
  # set.bitcoinrpc.py
  python /home/joinmarket/set.bitcoinrpc.py --network=mainnet \
  --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host \
  --rpc_port=$rpc_port --rpc_wallet=$rpc_wallet
}