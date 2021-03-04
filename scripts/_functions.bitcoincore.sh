#!/bin/bash

# downloadBitcoinCore
function downloadBitcoinCore() {
  # set version
  # https://bitcoincore.org/en/download/
  bitcoinVersion="0.21.0"

  # needed to check code signing
  laanwjPGP="01EA5486DE18A882D4C2684590C8019E36C2E964"

  echo "# Detecting CPU architecture ..."
  isARM=$(uname -m | grep -c 'arm')
  isAARCH64=$(uname -m | grep -c 'aarch64')
  isX86_64=$(uname -m | grep -c 'x86_64')
  if [ ${isARM} -eq 0 ] && [ ${isAARCH64} -eq 0 ] && [ ${isX86_64} -eq 0 ]; then
    echo "# !!! FAIL !!!"
    echo "# Can only build on ARM, aarch64, x86_64 not on:"
    uname -m
    exit 1
  else
    echo "# OK running on $(uname -m) architecture."
  fi

  echo
  echo "# *** PREPARING BITCOIN ***"
  # prepare directories
  sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
  cd /home/joinmarket/download || exit 1 

  # download, check and import signer key
  if [ ! -f "laanwj-releases.asc" ];then
    sudo -u joinmarket wget https://bitcoin.org/laanwj-releases.asc
  fi
  if [ ! -f "laanwj-releases.asc" ];then
    echo "# !!! FAIL !!! Could not download laanwj-releases.asc"
    exit 1
  fi
  gpg laanwj-releases.asc 
  fingerprint=$(gpg ./laanwj-releases.asc 2>/dev/null | grep "${laanwjPGP}" -c)
  if [ ${fingerprint} -lt 1 ]; then
    echo
    echo "# !!! BUILD WARNING --> Bitcoin PGP author not as expected"
    echo "# Should contain laanwjPGP: ${laanwjPGP}"
    echo "# PRESS ENTER to TAKE THE RISK if you think all is OK"
    read key
  fi
  gpg --import laanwj-releases.asc

  # download signed binary sha256 hash sum file and check
  if [ ! -f "SHA256SUMS.asc" ];then
    sudo -u joinmarket wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc
  else
    echo "SHA256SUMS.asc is already present"
  fi
  verifyResult=$(gpg --verify SHA256SUMS.asc 2>&1)
  goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
  echo "# goodSignature(${goodSignature})"
  correctKey=$(echo ${verifyResult} |  grep "using RSA key ${laanwjPGP: -16}" -c)
  echo "# correctKey(${correctKey})"
  if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
    echo
    echo "# !!! BUILD FAILED --> PGP Verify not OK / signature(${goodSignature}) verify(${correctKey})"
    echo "# Deleting the mismatched file"
    rm -f SHA256SUMS.asc 
    exit 1
  else
    echo
    echo "# ****************************************"
    echo "# OK --> BITCOIN MANIFEST IS CORRECT"
    echo "# ****************************************"
    echo
  fi

  # get the sha256 value for the corresponding platform from signed hash sum file
  if [ ${isARM} -eq 1 ] ; then
    bitcoinOSversion="arm-linux-gnueabihf"
  fi
  if [ ${isAARCH64} -eq 1 ] ; then
    bitcoinOSversion="aarch64-linux-gnu"
  fi
  if [ ${isX86_64} -eq 1 ] ; then
    bitcoinOSversion="x86_64-linux-gnu"
  fi
  bitcoinSHA256=$(grep -i "$bitcoinOSversion" SHA256SUMS.asc | cut -d " " -f1)

  echo
  echo "# BITCOIN v${bitcoinVersion} for ${bitcoinOSversion}"

  # download resources
  binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
  if [ ! -f "./${binaryName}" ];then
    sudo -u joinmarket wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName}
  else
    echo "# ${binaryName} was already downloaded"
  fi
  if [ ! -f "./${binaryName}" ];then
      echo "# !!! FAIL !!! ${binaryName} is not present"
      exit 1
  fi

  # check binary checksum test
  binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
  if [ "${binaryChecksum}" != "${bitcoinSHA256}" ]; then
    echo "# !!! FAIL !!! Downloaded BITCOIN BINARY not matching SHA256 checksum: ${bitcoinSHA256}"
    echo "# Deleting the corrupt file"
    rm -f ${binaryName}
    exit 1
  else
    echo
    echo "# ****************************************"
    echo "# OK --> VERIFIED BITCOIN CHECKSUM CORRECT"
    echo "# ****************************************"
    echo
  fi
}

function installBitcoinCore() {
  downloadBitcoinCore

  if [ -f /home/joinmarket/bitcoin/bitcoind ];then
    installedVersion=$(/home/joinmarket/bitcoin/bitcoind --version | grep version)
    echo "${installedVersion} is already installed"
  else
    echo "# Installing Bitcoin Core v${bitcoinVersion}"
    sudo -u joinmarket tar -xvf ${binaryName}
    sudo -u joinmarket mkdir -p /home/joinmarket/bitcoin
    sudo install -m 0755 -o root -g root -t /home/joinmarket/bitcoin bitcoin-${bitcoinVersion}/bin/*  
  fi

  installed=$(/home/joinmarket/bitcoin/bitcoind --version | grep "${bitcoinVersion}" -c)
  if [ ${installed} -lt 1 ]; then
    echo
    echo "!!! BUILD FAILED --> Was not able to install bitcoind version(${bitcoinVersion})"
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
-pid=/home/joinmarket/bitcoin/bitcoind.pid
KillMode=process
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/signetd.service
  sudo systemctl enable signetd
  echo "# OK - the bitcoin daemon on signet service is now enabled"

  # add aliases
  if [ $(alias | grep -c signet) -eq 0 ];then 
    alias signet-cli="/home/joinmarket/bitcoin/bitcoin-cli -signet"
    alias signetd="/home/joinmarket/bitcoin/bitcoind -signet"
    sudo bash -c "echo 'alias signet-cli=\"/home/joinmarket/bitcoin/bitcoin-cli -signet\"' >> /home/joinmarket/_commands.sh"
    sudo bash -c "echo 'alias signetd=\"/home/joinmarket/bitcoin/bitcoind -signet\"' >> /home/joinmarket/_commands.sh"
  fi

  sudo systemctl start signetd

  echo
  echo "# Installed $(/home/joinmarket/bitcoin/bitcoind --version | grep version)"
  echo 
  echo "# Monitor the signet bitcoind with: tail -f ~/.bitcoin/signet/debug.log"
  echo

  if [ ! -f /home/joinmarket/.bitcoin/signet/wallets/wallet.dat/wallet.dat ];then
    echo "# Create wallet.dat for signet ..."
    sleep 10
    sudo -u joinmarket /home/joinmarket/bitcoin/bitcoin-cli -signet createwallet wallet.dat
  fi
}

setJMconfigToSignet() {
  echo "# editing the joinmarket.cfg"
  # rpc_user
  sed -i "s/^rpc_user =.*/rpc_user = joinmarket/g" $JMcfgPath
  # rpc_password
  RPCpassword=$(sudo cat /home/joinmarket/.bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
  sed -i "s/^rpc_password =.*/rpc_password = $RPCpassword/g" $JMcfgPath
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
  sudo tail -fn1000 $logFilePath
}

# getRPC - reads the RPC settings from the joinmarket.cfg
function getRPC {
  echo "# Reading the bitcoind RPC settings from the joinmarket.cfg"
  rpc_user="$(awk '/rpc_user / {print $3}' < $JMcfgPath)"
  rpc_pass="$(awk '/rpc_password / {print $3}' < $JMcfgPath)"
  rpc_host="$(awk '/rpc_host / {print $3}' < $JMcfgPath)"
  rpc_port="$(awk '/rpc_port / {print $3}' < $JMcfgPath)"
  rpc_wallet="$(awk '/rpc_wallet_file / {print $3}' < $JMcfgPath)"
  if [ ${#1} -gt 0 ]&&[ $1 = print ];then
    echo "$rpc_user $rpc_pass $rpc_host $rpc_port $rpc_wallet"
  fi
}

# checkRPCwallet <wallet>
function checkRPCwallet {
  getRPC
  if [ ${#1} -eq 0 ];then
    rpc_wallet=$rpc_wallet
  else
    rpc_wallet=$1
  fi
  echo "# Making sure the set $rpc_wallet wallet is present in bitcoind"
  connectionOutput=$(mktemp -p /dev/shm/)
  walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
  if [ $walletFound -eq 0 ]; then
    echo "# Setting a watch only wallet for the remote Bitcoin Core named $rpc_wallet"
    customRPC "# Create the bitcoind wallet" "createwallet" "$rpc_wallet"
    echo
    walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
    if [ $walletFound -eq 0 ]; then
      echo "# Making sure the set $rpc_wallet wallet is loaded in bitcoind"
      echo
      customRPC "# Load wallet in bitcoind" "loadwallet" "$rpc_wallet"
      walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
    fi
    echo 
  fi
  echo "# The wallet: $rpc_wallet is present and loaded in the connected bitcoind"
}

# customRPC - sends a custom RPC command
# $1=id $2=method $3=string params
function customRPC {
  getRPC
  tor=""
  if [ $(echo $rpc_host | grep -c .onion) -gt 0 ]; then
    tor="torify"
    echo "# Connecting over Tor..."
    echo
  fi
  echo "# Using the RPC command:"
  is_int () { test "$@" -eq "$@" 2> /dev/null; }
  if is_int "$3" ||[ ${#3} -eq 0 ]; then
    echo "$tor curl -sS --data-binary\
 '{\"jsonrpc\": \"1.0\", \"id\":\"$1\", \"method\": \"$2\", \"params\": [$3] }'\
 http://$rpc_user:rpc_pass(redacted)@rpc_host(redacted):$rpc_port"
    echo
    $tor curl -sS --data-binary \
    '{"jsonrpc": "1.0", "id":"'"$1"'", "method": "'"$2"'", "params": ['"$3"'] }' \
    http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port | jq .
  else
    echo "$tor curl -sS --data-binary\
 '{\"jsonrpc\": \"1.0\", \"id\":\"$1\", \"method\": \"$2\", \"params\": [\"$3\"] }'\
 http://$rpc_user:rpc_pass(redacted)@rpc_host(redacted):$rpc_port"
    echo
    $tor curl -sS --data-binary \
    '{"jsonrpc": "1.0", "id":"'"$1"'", "method": "'"$2"'", "params": ["'"$3"'"] }' \
    http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port | jq .
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
    rpc_user="raspibolt"
    rpc_pass=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf|grep rpcpassword|cut -c 13-)
  elif [ $runningEnv = standalone ];then
    rpc_user=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf|grep rpcuser|cut -c 9-)
    rpc_pass=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf|grep rpcpassword|cut -c 13-)
  fi
  # set.bitcoinrpc.py 
  python /home/joinmarket/set.bitcoinrpc.py --network=mainnet \
  --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host \
  --rpc_port=$rpc_port --rpc_wallet=$rpc_wallet
}