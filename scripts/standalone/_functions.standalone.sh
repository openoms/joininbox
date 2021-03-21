#!/bin/bash

function addUserStore() {
  if [ ! -d /home/store/app-data ];then
    echo "# Adding the user: store"
    sudo adduser --disabled-password --gecos "" store
    sudo -u store mkdir /home/store/app-data
  else
    echo "# The folder /home/store/app-data is present already"
  fi 
}

function moveSignetData() {
  if [ -f /etc/systemd/system/signetd.service ];then
    sudo systemctl stop signetd
    sudo mv /home/joinmarket/.bitcoin /home/store/app-data/
    sudo ln -s /home/store/app-data/.bitcoin /home/bitcoin/
    sudo chown -R joinmarket:joinmarket /home/joinmarket/.bitcoin/
    sudo systemctl start signetd
  fi
}

function makeEncryptedFolder(){
  # TODO
  # make encrypted file

  # mount to /mnt/encrypted/
  
  # move all from app-data
  sudo mv /home/store/app-data /mnt/encrypted/
  # symlink
  sudo ln -s /mnt/encrypted/app-data /home/store/
}

function downloadSnapShot() {
  echo "# Check available diskspace"
  FREE=$(df -k --output=avail "$PWD" | tail -n1) # df -k not df -h
  if [ $FREE -lt 12582912 ];then                 # 12G = 12*1024*1024k
    echo "# The free space is only $FREE bytes!"
    echo "# Would need ~12GB free space to download and extract the snapshot."
    echo "# Press ENTER to continue to download regardless or CTRL+C to exit." 
    read key
  else
    echo "# OK, more than 12GB is free!"
  fi
  sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
  cd /home/joinmarket/download || exit 1
  hashFileName="latest.signed.txt"
  sudo rm $hashFileName
  wget https://prunednode.today/$hashFileName || exit 1
  downloadFileName=$(grep .zip < $hashFileName | awk '{print $2}')
  downloadLink="https://prunednode.today/$downloadFileName"
  
  echo "# Import the PGP keys of Stepan Snigirev"
  curl https://stepansnigirev.com/ss-specter-release.asc | gpg --import || exit 1
  
  echo "# Verifying the signature of the hash ..."
  verifyResult=$(gpg --verify $hashFileName 2>&1)
  goodSignature=$(echo ${verifyResult} | grep -c 'Good signature')
  echo "# goodSignature (${goodSignature})"
  if [ ${goodSignature} -eq 0 ];then
    echo "# Invalid signature on $hashFileName"
    echo "# Press ENTER to remove the invalid file or CTRL+C to abort."
    read key
    echo "# Removing $hashFileName"
    rm -f $hashFileName
    exit 1
  fi

  if [ ! -f $downloadFileName ];then
    echo
    echo "# Downloading $downloadLink ..."
    echo
    wget $downloadLink
  fi

  echo "# Verifying the hash (takes time) ..."
  verifyHash=$(sha256sum -c $hashFileName 2>&1)
  goodHash=$(echo ${verifyHash} | grep -c OK)
  echo "# goodHash ($goodHash)"
  if [ ${goodSignature} -lt 1 ] || [ ${goodHash} -lt 1 ]; then
    echo
    echo "# Download failed --> PGP Verify not OK / signature(${goodSignature})"
    echo "# Press ENTER to remove the invalid files or CTRL+C to abort."
    read key
    echo "# Removing the downloaded files"
    rm -f $hashFileName
    rm -f $downloadFileName
    exit 1
  else
    echo
    echo "# The PGP signature and the hash of the downloaded snapshot is correct"
  fi
  
  echo "# Exracting to /home/store/app-data/.bitcoin ..."
  FREE=$(df -k --output=avail "$PWD" | tail -n1) # df -k not df -h
  if [ $FREE -lt 7340032 ];then                 # 7G = 7*1024*1024k
    echo "# The free space is only $FREE bytes!"
    echo "# Would need ~7GB free space to extract the snapshot."
    echo "# Press ENTER to continue to download regardless or CTRL+C to exit." 
    read key
  else
    echo "# OK, more than 7GB is free!"
  fi
  addUserStore
  sudo mkdir -p /home/store/app-data/.bitcoin
  echo "# Make sure bitcoind is not running"
  sudo systemctl stop bitcoind
  if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
    echo "# Back up bitcoin.conf"
    sudo -u bitcoin mv /home/bitcoin/.bitcoin/bitcoin.conf \
    /home/bitcoin/.bitcoin/bitcoin.conf.backup
  fi
  echo "# Check unzip"
  sudo apt install -y unzip
  sudo unzip -o $downloadFileName -d /home/store/app-data/.bitcoin
  if [ -f /home/bitcoin/.bitcoin/bitcoin.conf.backup ];then
    echo "# Restore bitcoin.conf"
    sudo -u bitcoin mv -f /home/bitcoin/.bitcoin/bitcoin.conf.backup \
    /home/bitcoin/.bitcoin/bitcoin.conf
  fi
  echo "# Making sure user: bitcoin exists"
  sudo adduser --disabled-password --gecos "" bitcoin
  sudo chown -R bitcoin:bitcoin /home/store/app-data/.bitcoin
}

function installBitcoinCoreStandalone() {
  downloadBitcoinCore

  if [ -f /home/bitcoin/bitcoin/bitcoind ];then
    installedVersion=$(/home/bitcoin/bitcoin/bitcoind --version | grep version)
    echo "${installedVersion} is already installed"
  else
    echo "# Adding the user: bitcoin"
    sudo adduser --disabled-password --gecos "" bitcoin
    echo "# Installing Bitcoin Core v${bitcoinVersion}"
    sudo -u bitcoin mkdir -p /home/bitcoin/bitcoin
    cd /home/joinmarket/download/bitcoin-${bitcoinVersion}/bin/ || exit 1
    sudo install -m 0755 -o root -g root -t /home/bitcoin/bitcoin ./*
  fi
  if [ "$(grep -c "/home/bitcoin/bitcoin" < /etc/profile)" -eq 0 ];then
    echo "# Add /home/bitcoin/bitcoin to global PATH"
    echo "PATH=/home/bitcoin/bitcoin:$PATH" | sudo tee -a /etc/profile
  fi
  installed=$(/home/bitcoin/bitcoin/bitcoind --version | grep "${bitcoinVersion}" -c)
  if [ ${installed} -lt 1 ]; then
    echo
    echo "!!! BUILD FAILED --> Was not able to install bitcoind version(${bitcoinVersion})"
    exit 1
  fi

  # bitcoin.conf
  if [ -f /home/store/app-data/.bitcoin/bitcoin.conf ];then
    if [ $(grep -c rpcpassword < /home/store/app-data/.bitcoin/bitcoin.conf) -eq 0 ];then
      sudo rm /home/store/app-data/.bitcoin/bitcoin.conf
    fi
  fi

  echo "# symlink to /home/bitcoin/"
  sudo rm -rf /home/bitcoin/.bitcoin # not a symlink, delete
  sudo mkdir -p /home/store/app-data/.bitcoin
  sudo ln -s /home/store/app-data/.bitcoin /home/bitcoin/

  if [ ! -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
    randomRPCpass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c20)
    echo "
# bitcoind configuration for mainnet

# Connection settings
rpcuser=joininbox
rpcpassword=$randomRPCpass

prune=1000
server=1
fallbackfee=0.0002

onlynet=onion
proxy=127.0.0.1:9050
" | sudo tee /home/bitcoin/.bitcoin/bitcoin.conf 
  else
    echo "# /home/bitcoin/.bitcoin/bitcoin.conf is present"
  fi
  sudo chown -R bitcoin:bitcoin /home/store/app-data/.bitcoin
  sudo chown -R bitcoin:bitcoin /home/bitcoin/
}

function installMainnet() {
  source /home/joinmarket/_functions.bitcoincore.sh
  removeSignetdService
  sudo systemctl stop bitcoind
  # /etc/systemd/system/bitcoind.service
  echo "
[Unit]
Description=Bitcoin daemon on mainnet
[Service]
User=bitcoin
Group=bitcoin
Type=forking
PIDFile=/home/bitcoin/bitcoin/bitcoind.pid
ExecStart=/home/bitcoin/bitcoin/bitcoind -daemon \
-pid=/home/bitcoin/bitcoin/bitcoind.pid
KillMode=process
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/bitcoind.service
  sudo systemctl daemon-reload
  sudo systemctl enable bitcoind
  echo "# OK - the bitcoind.service is now enabled"

  # add aliases
  if [ $(alias | grep -c "sudo -u bitcoin /home/bitcoin/bitcoin/bitcoin-cli") -eq 0 ];then 
    sudo bash -c "echo 'alias bitcoin-cli=\"sudo -u bitcoin /home/bitcoin/bitcoin/bitcoin-cli\"' >> /home/joinmarket/_commands.sh"
    sudo bash -c "echo 'alias bitcoind=\"sudo -u bitcoin /home/bitcoin/bitcoin/bitcoind\"' >> /home/joinmarket/_commands.sh"
  fi

  sudo systemctl start bitcoind
  echo
  echo "# Installed $(/home/bitcoin/bitcoin/bitcoind --version | grep version)"
  echo 
  echo "# Monitor the bitcoind with: sudo tail -f /home/bitcoin/.bitcoin/mainnet/debug.log"
  echo

  if [ ! -f /home/bitcoin/.bitcoin/mainnet/wallets/wallet.dat/wallet.dat ];then
    echo "# Create wallet.dat ..."
    sleep 10
    sudo -u bitcoin /home/bitcoin/bitcoin/bitcoin-cli createwallet wallet.dat
  fi
}
