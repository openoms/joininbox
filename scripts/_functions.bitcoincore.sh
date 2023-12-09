#!/bin/bash

# paths
walletPath="/home/joinmarket/.joinmarket/wallets/"
JMcfgPath="/home/joinmarket/.joinmarket/joinmarket.cfg"
joininConfPath="/home/joinmarket/joinin.conf"

# downloadBitcoinCore
function downloadBitcoinCore() {
  # set version
  # https://bitcoincore.org/en/download/
  bitcoinVersion="25.0"

  if bitcoin-cli --version | grep $bitcoinVersion >/dev/null; then
    echo "# Bitcoin Core $bitcoinVersion is already installed"
    return 0
  fi

  echo
  echo "# *** PREPARING BITCOIN ***"
  # prepare directories
  sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
  cd /home/joinmarket/download || exit 1

  echo "# Receive signer keys"
  curl -s "https://api.github.com/repos/bitcoin-core/guix.sigs/contents/builder-keys" |
    jq -r '.[].download_url' | while read url; do curl -s "$url" | gpg --import; done

  # download signed binary sha256 hash sum file
  sudo -u joinmarket wget --prefer-family=ipv4 --progress=bar:force -O SHA256SUMS https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS
  # download the signed binary sha256 hash sum file and check
  sudo -u joinmarket wget --prefer-family=ipv4 --progress=bar:force -O SHA256SUMS.asc https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc

  if gpg --verify SHA256SUMS.asc; then
    echo
    echo "****************************************"
    echo "OK --> BITCOIN MANIFEST IS CORRECT"
    echo "****************************************"
    echo
  else
    echo
    echo "# BUILD FAILED --> the PGP verification failed"
    exit 1
  fi

  # detect CPU architecture & fitting download link
  if [ $(uname -m | grep -c 'arm') -eq 1 ]; then
    bitcoinOSversion="arm-linux-gnueabihf"
  fi
  if [ $(uname -m | grep -c 'aarch64') -eq 1 ]; then
    bitcoinOSversion="aarch64-linux-gnu"
  fi
  if [ $(uname -m | grep -c 'x86_64') -eq 1 ]; then
    bitcoinOSversion="x86_64-linux-gnu"
  fi

  echo
  echo "*** BITCOIN CORE v${bitcoinVersion} for ${bitcoinOSversion} ***"

  # download resources
  binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
  if [ ! -f "./${binaryName}" ]; then
    sudo -u joinmarket wget --prefer-family=ipv4 --progress=bar:force https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName}
  fi
  if [ ! -f "./${binaryName}" ]; then
    echo "# FAIL - Could not download the BITCOIN BINARY"
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
      echo "# FAIL - Downloaded BITCOIN BINARY does not match SHA256 checksum: ${bitcoinSHA256}"
      rm -v ./${binaryName}
      exit 1
    else
      echo
      echo "********************************************"
      echo "OK --> VERIFIED BITCOIN CORE BINARY CHECKSUM"
      echo "********************************************"
      echo
    fi
    echo
    echo "# Extracting to /home/joinmarket/download/bitcoin-${bitcoinVersion}"
    sudo -u joinmarket tar -xvf ${binaryName}
    echo
  fi
}

function installBitcoinCore() {
  if [ ${runningEnv} != "raspiblitz" ]; then
    downloadBitcoinCore

    echo "# Installing Bitcoin Core v${bitcoinVersion}"
    sudo -u joinmarket mkdir -p /home/joinmarket/bitcoin
    cd /home/joinmarket/download/bitcoin-${bitcoinVersion}/bin/ || exit 1
    sudo install -m 0755 -o root -g root -t /home/joinmarket/bitcoin ./*

    if [ "$(grep -c "/home/joinmarket/bitcoin" </home/joinmarket/.profile)" -eq 0 ]; then
      echo "# Add /home/joinmarket/bitcoin to the local PATH"
      echo "PATH=/home/joinmarket/bitcoin:$PATH" | sudo tee -a /home/joinmarket/.profile
    fi
    installed=$(/home/joinmarket/bitcoin/bitcoind --version | grep -c "Bitcoin Core version")
    if [ ${installed} -lt 1 ]; then
      echo
      echo "# BUILD FAILED --> Was not able to install Bitcoin Core"
      exit 1
    fi

    # bitcoin.conf
    if [ ! -f /home/joinmarket/.bitcoin/bitcoin.conf ]; then
      mkdir -p /home/joinmarket/.bitcoin
      randomRPCpass=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c8)
      cat >/home/joinmarket/.bitcoin/bitcoin.conf <<EOF
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
  fi
}

function removeSignetdService() {
  if [ -f "/etc/systemd/system/signetd.service" ]; then
    sudo systemctl stop signetd
    sudo systemctl disable signetd
    sudo rm -f /etc/systemd/system/signetd.service
    echo "# The signetd service is stopped and removed"
    echo
  fi
}

function installSignet() {
  if [ "${runningEnv}" = "raspiblitz" ]; then
    sudo -u admin /home/admin/config.scripts/bitcoin.install.sh on signet
  else
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

    if [ $(sudo cat /home/joinmarket/.bitcoin/bitcoin.conf | grep -c "signet.addnode") -eq 0 ]; then
      echo "\
signet.addnode=s7fcvn5rblem7tiquhhr7acjdhu7wsawcph7ck44uxyd6sismumemcyd.onion:38333
signet.addnode=6megrst422lxzsqvshkqkg6z2zhunywhyrhy3ltezaeyfspfyjdzr3qd.onion:38333
signet.addnode=jahtu4veqnvjldtbyxjiibdrltqiiighauai7hmvknwxhptsb4xat4qd.onion:38333
signet.addnode=f4kwoin7kk5a5kqpni7yqe25z66ckqu6bv37sqeluon24yne5rodzkqd.onion:38333
signet.addnode=nsgyo7begau4yecc46ljfecaykyzszcseapxmtu6adrfagfrrzrlngyd.onion:38333" |
        sudo tee -a /home/joinmarket/.bitcoin/bitcoin.conf
    fi

    # add to path
    if [ $(sudo cat /etc/profile | grep -c "/home/joinmarket/bitcoin/") -eq 0 ]; then
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
  fi
}

setJMconfigToSignet() {
  echo "## editing the joinmarket.cfg with signet values."
  if [ ${#network} -eq 0 ] || [ "${network}" = "mainnet" ] || [ "${runningEnv}" = "raspiblitz" ]; then
    bitcoinUser="bitcoin"
  elif [ "${network}" = "signet" ]; then
    bitcoinUser="joinmarket"
  fi
  # rpc_user
  RPCUSERSIGNET=$(sudo cat /home/${bitcoinUser}/.bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
  sed -i "s/^rpc_user =.*/rpc_user = $RPCUSERSIGNET/g" $JMcfgPath
  echo "# rpc_user = $RPCUSERSIGNET"
  # rpc_password
  RPCPWSIGNET=$(sudo cat /home/${bitcoinUser}/.bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
  sed -i "s/^rpc_password =.*/rpc_password = $RPCPWSIGNET/g" $JMcfgPath
  echo "# rpc_password = $RPCPWSIGNET"
  # rpc_wallet_file
  sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/g" $JMcfgPath
  echo "# using the bitcoind wallet: wallet.dat"
  # rpc_host
  sed -i "s/^rpc_host =.*/rpc_host = 127.0.0.1/g" $JMcfgPath
  echo "# rpc_host = 127.0.0.1"
  # rpc_port
  sed -i "s/^rpc_port =.*/rpc_port = 38332/g" $JMcfgPath
  echo "# rpc_port = 38332"
  # network
  sed -i "s/^network =.*/network = signet/g" $JMcfgPath
  echo "# network = signet "
  # minimum_makers
  sed -i "s/^minimum_makers =.*/minimum_makers = 1/g" $JMcfgPath
  echo "# minimum_makers = 1"

  echo "# Set signet directory nodes"
  # comment mainnet
  sed -i \
    "s/^directory_nodes = 3kxw6lf5vf6y26emzwgibzhrzhmhqiw6ekrek3nqfjjmhwznb2moonad.onion:5222,jmdirjmioywe2s5jad7ts6kgcqg66rj6wujj6q77n6wbdrgocqwexzid.onion:5222,bqlpq6ak24mwvuixixitift4yu42nxchlilrcqwk2ugn45tdclg42qid.onion:5222/\
#directory_nodes = 3kxw6lf5vf6y26emzwgibzhrzhmhqiw6ekrek3nqfjjmhwznb2moonad.onion:5222,jmdirjmioywe2s5jad7ts6kgcqg66rj6wujj6q77n6wbdrgocqwexzid.onion:5222,bqlpq6ak24mwvuixixitift4yu42nxchlilrcqwk2ugn45tdclg42qid.onion:5222/g" \
    $JMcfgPath
  # uncomment signet
  sed -i \
    "s/^# directory_nodes = rr6f6qtleiiwic45bby4zwmiwjrj3jsbmcvutwpqxjziaydjydkk5iad.onion:5222,k74oyetjqgcamsyhlym2vgbjtvhcrbxr4iowd4nv4zk5sehw4v665jad.onion:5222,y2ruswmdbsfl4hhwwiqz4m3sx6si5fr6l3pf62d4pms2b53wmagq3eqd.onion:5222/\
directory_nodes = rr6f6qtleiiwic45bby4zwmiwjrj3jsbmcvutwpqxjziaydjydkk5iad.onion:5222,k74oyetjqgcamsyhlym2vgbjtvhcrbxr4iowd4nv4zk5sehw4v665jad.onion:5222,y2ruswmdbsfl4hhwwiqz4m3sx6si5fr6l3pf62d4pms2b53wmagq3eqd.onion:5222/g" \
    $JMcfgPath

  # set joinin.conf value
  /home/joinmarket/set.value.sh set network signet ${joininConfPath}
}

function showBitcoinLogs() {
  if [ $# -eq 0 ]; then
    lines=""
    echo "# Show the default number of lines"
  else
    lines="-n $1"
    echo "# Show $lines number of lines"
  fi
  source ${joininConfPath}
  if [ ${#network} -eq 0 ] || [ "${network}" = "mainnet" ] || [ "${runningEnv}" = "raspiblitz" ]; then
    bitcoinUser="bitcoin"
  elif [ "${network}" = "signet" ]; then
    bitcoinUser="joinmarket"
  fi
  if [ "${network}" = mainnet ]; then
    logFilePath="/home/${bitcoinUser}/.bitcoin/debug.log"
  elif [ "${network}" = signet ]; then
    logFilePath="/home/${bitcoinUser}/.bitcoin/signet/debug.log"
  fi
  dialog \
    --title "Monitoring the ${network} logs" \
    --msgbox "
Will tail the bitcoin ${network} logfile from:

$logFilePath

Press CTRL+C to exit and type 'menu' for the GUI." 10 54
  sudo tail -f $lines $logFilePath
}

# getRPC - reads the RPC settings from the joinmarket.cfg
function getRPC {
  echo "# Reading the bitcoind RPC settings from the joinmarket.cfg"
  rpc_user="$(awk '/^rpc_user / {print $3}' <$JMcfgPath)"
  rpc_pass="$(awk '/^rpc_password / {print $3}' <$JMcfgPath)"
  rpc_host="$(awk '/^rpc_host / {print $3}' <$JMcfgPath)"
  rpc_port="$(awk '/^rpc_port / {print $3}' <$JMcfgPath)"
  rpc_wallet="$(awk '/^rpc_wallet_file / {print $3}' <$JMcfgPath)"
  if [ ${#1} -gt 0 ] && [ $1 = print ]; then
    echo "$rpc_user $rpc_pass $rpc_host $rpc_port $rpc_wallet"
  fi
}

# checkRPCwallet <wallet>
function checkRPCwallet {
  getRPC
  if [ $# -eq 0 ]; then
    rpc_wallet=$rpc_wallet
  else
    rpc_wallet=$1
  fi
  echo "# Making sure the set $rpc_wallet wallet is present in bitcoind"
  trap 'rm -f "$connectionOutput"' EXIT
  connectionOutput=$(mktemp -p /dev/shm/)
  walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
  if [ $walletFound -eq 0 ]; then
    echo "# Setting a watch only wallet in Bitcoin Core named $rpc_wallet"
    tor=""
    if [ $(echo $rpc_host | grep -c .onion) -gt 0 ]; then
      tor="torsocks"
      echo "# Connecting over Tor..."
      echo
    fi
    #TODO rewrite customRPC to support multiple params
    $tor curl -sS --data-binary \
      '{"jsonrpc": "1.0", "id":"# Create the bitcoind wallet", "method": "createwallet", "params": {"wallet_name":"'"$rpc_wallet"'","descriptors":false}}' \
      http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet | jq .
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
  if [ ${#4} -eq 0 ]; then
    print="no"
  else
    print=$4
  fi
  if [ $print = print ]; then
    echo print
  fi
  tor=""
  if [ $(echo $rpc_host | grep -c .onion) -gt 0 ]; then
    tor="torsocks"
    echo "# Connecting over Tor..."
    echo
  fi
  is_int() { test "$@" -eq "$@" 2>/dev/null; }
  if is_int "$3" || [ ${#3} -eq 0 ]; then
    if [ $print = print ]; then
      echo "# Using the RPC command:"
      echo "$tor curl -sS --data-binary\
 '{\"jsonrpc\": \"1.0\", \"id\":\"$1\", \"method\": \"$2\", \"params\": [$3] }'\
 http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet"
      echo
    fi
    $tor curl -sS --data-binary \
      '{"jsonrpc": "1.0", "id":"'"$1"'", "method": "'"$2"'", "params": ['"$3"'] }' \
      http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port/wallet/$rpc_wallet | jq .
  else
    if [ $print = print ]; then
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
  if [ ${#1} -gt 0 ]; then
    network=$1
  else
    source ${joininConfPath}
  fi
  echo "# Setting connection to the local Bitcoin node on ${network}"
  rpc_host="127.0.0.1"
  if [ "${network}" = mainnet ]; then
    rpc_port="8332"
  elif [ "${network}" = signet ]; then
    rpc_port="38332"
  elif [ "${network}" = testnet ]; then
    rpc_port="18332"
  fi
  rpc_wallet="wallet.dat"
  if [ $runningEnv = raspiblitz ]; then
    rpc_user=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
    rpc_pass=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
  elif [ $runningEnv = mynode ]; then
    rpc_user=mynode
    rpc_pass=$(sudo cat /mnt/hdd/mynode/settings/.btcrpcpw)
  elif [ $runningEnv = standalone ]; then
    rpc_user=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
    rpc_pass=$(sudo cat /home/bitcoin/.bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
  fi
  # set.bitcoinrpc.py
  python /home/joinmarket/set.bitcoinrpc.py --network=${network} \
    --rpc_user="$rpc_user" --rpc_pass="$rpc_pass" --rpc_host=$rpc_host \
    --rpc_port=$rpc_port --rpc_wallet=$rpc_wallet

  # set joinin.conf value
  /home/joinmarket/set.value.sh set network ${network} ${joininConfPath}
}
