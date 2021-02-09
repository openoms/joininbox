#!/bin/bash

# Concise instructions on setting up Joinmarket for testing on signet
# https://gist.github.com/AdamISZ/325716a66c7be7dd3fc4acdfce449fb1

# installBitcoinCore
function installBitcoinCoreSignet() {
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
sudo rm -rf /home/joinmarket/download 2>/dev/null
sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
cd /home/joinmarket/download || exit 1 

# download, check and import signer key
sudo -u joinmarket wget https://bitcoin.org/laanwj-releases.asc
if [ ! -f "./laanwj-releases.asc" ]
then
  echo "# !!! FAIL !!! Download laanwj-releases.asc not success."
  exit 1
fi
gpg ./laanwj-releases.asc
fingerprint=$(gpg ./laanwj-releases.asc 2>/dev/null | grep "${laanwjPGP}" -c)
if [ ${fingerprint} -lt 1 ]; then
  echo
  echo "# !!! BUILD WARNING --> Bitcoin PGP author not as expected"
  echo "# Should contain laanwjPGP: ${laanwjPGP}"
  echo "# PRESS ENTER to TAKE THE RISK if you think all is OK"
  read key
fi
gpg --import ./laanwj-releases.asc

# download signed binary sha256 hash sum file and check
sudo -u joinmarket wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc
verifyResult=$(gpg --verify SHA256SUMS.asc 2>&1)
goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
echo "# goodSignature(${goodSignature})"
correctKey=$(echo ${verifyResult} |  grep "using RSA key ${laanwjPGP: -16}" -c)
echo "# correctKey(${correctKey})"
if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
  echo
  echo "# !!! BUILD FAILED --> PGP Verify not OK / signature(${goodSignature}) verify(${correctKey})"
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
echo "# *** BITCOIN v${bitcoinVersion} for ${bitcoinOSversion} ***"

# download resources
binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
sudo -u joinmarket wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName}
if [ ! -f "./${binaryName}" ]
then
    echo "# !!! FAIL !!! Download BITCOIN BINARY not success."
    exit 1
fi

# check binary checksum test
binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
if [ "${binaryChecksum}" != "${bitcoinSHA256}" ]; then
  echo "# !!! FAIL !!! Downloaded BITCOIN BINARY not matching SHA256 checksum: ${bitcoinSHA256}"
  exit 1
else
  echo
  echo "# ****************************************"
  echo "# OK --> VERIFIED BITCOIN CHECKSUM CORRECT"
  echo "# ****************************************"
  echo
fi

echo "# Stopping signetd"
sudo systemctl stop signetd
echo

echo "Installing Bitcoin Core v${bitcoinVersion}"
sudo -u joinmarket tar -xvf ${binaryName}
sudo -u joinmarket mkdir -p /home/joinmarket/bitcoin
sudo install -m 0755 -o root -g root -t /home/joinmarket/bitcoin bitcoin-${bitcoinVersion}/bin/*

installed=$(/home/joinmarket/bitcoin/bitcoind --version | grep "${bitcoinVersion}" -c)
if [ ${installed} -lt 1 ]; then
  echo
  echo "!!! BUILD FAILED --> Was not able to install bitcoind version(${bitcoinVersion})"
  exit 1
fi

# bitcoin.conf
mkdir -p /home/joinmarket/.bitcoin
randomRPCpass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c20)
cat > /home/joinmarket/.bitcoin/bitcoin.conf <<EOF
# bitcoind configuration

# Connection settings
rpcuser=joinmarket
rpcpassword=$randomRPCpass

onlynet=onion
proxy=127.0.0.1:9050

[signet] 
wallet=wallet.dat
EOF

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
" | sudo tee -a /etc/systemd/system/signetd.service
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
# create signet wallet
/home/joinmarket/bitcoin/bitcoin-cli -signet createwallet wallet.dat

echo
echo "Installed $(/home/joinmarket/bitcoin/bitcoind --version | grep version)"
echo 
echo "# Monitor the signet bitcoind with: tail -f ~/.bitcoin/signet/debug.log"
}

setJMconfigToSignet() {
echo "# editing the joinmarket.cfg"
# rpc_user
sed -i "s/^rpc_user =.*/rpc_user = joinmarket/g" /home/joinmarket/.joinmarket/joinmarket.cfg
# rpc_password
PASSWORD_B=$(sudo cat /home/joinmarket/.bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
sed -i "s/^rpc_password =.*/rpc_password = $PASSWORD_B/g" /home/joinmarket/.joinmarket/joinmarket.cfg
# rpc_wallet_file
sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/g" /home/joinmarket/.joinmarket/joinmarket.cfg
echo "# using the bitcoind wallet: wallet.dat"
# rpc_host
sed -i "s/^rpc_host =.*/rpc_host = 127.0.0.1/g" /home/joinmarket/.joinmarket/joinmarket.cfg
# rpc_port
sed -i "s/^rpc_port =.*/rpc_port = 38332/g" /home/joinmarket/.joinmarket/joinmarket.cfg
# network
sed -i "s/^network =.*/network = signet/g" /home/joinmarket/.joinmarket/joinmarket.cfg
# minimum_makers
sed -i "s/^minimum_makers =.*/minimum_makers = 2/g" /home/joinmarket/.joinmarket/joinmarket.cfg
}

# check connectedRemoteNode var in joinin.conf
if ! grep -Eq "^connectedRemoteNode=" /home/joinmarket/joinin.conf; then
  echo "connectedRemoteNode=off" >> /home/joinmarket/joinin.conf
fi
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

if [ "$1" = "on" ]||[ "$1" = "signet" ]; then
  installBitcoinCoreSignet
  if [ $connectedRemoteNode = "on" ];then
    backupJMconf
  fi
  generateJMconfig 
  setJMconfigToSignet
elif [ "$1" = "off" ]||[ "$1" = "mainnet" ]; then
  if [ -f "/etc/systemd/system/signetd.service" ];then
    sudo systemctl stop signetd
    sudo systemctl disable signetd
    echo "# Bitcoin Core on signet service is stopped and disabled"
  fi
  isSignet=$(grep -c "network = signet" < /home/joinmarket/.joinmarket/joinmarket.cfg)
  if [ isSignet -gt 0 ];then
    echo "# Removing the joinmarket.cfg with signet settings"
    rm -f /home/joinmarket/.joinmarket/joinmarket.cfg
  else
    echo "# Signet is not set in joinmarket.cfg, leaving settings in place"
  fi
  generateJMconfig
fi
