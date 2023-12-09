#!/bin/bash

function addUserStore() {
  if [ ! -d /home/store/app-data ]; then
    echo "# Adding the user: store"
    sudo adduser --system --group --home /home/store store
    sudo -u store mkdir /home/store/app-data
    echo "# Add the joinmarket user to the store group"
    sudo usermod -aG store joinmarket
  else
    echo "# The folder /home/store/app-data is present already"
  fi
}

function moveSignetData() {
  if [ -f /etc/systemd/system/signetd.service ]; then
    sudo systemctl stop signetd
    sudo mv /home/joinmarket/.bitcoin /home/store/app-data/
    sudo ln -s /home/store/app-data/.bitcoin /home/bitcoin/
    sudo chown -R joinmarket:joinmarket /home/joinmarket/.bitcoin/
    sudo systemctl start signetd
  fi
}

function makeEncryptedFolder() {
  # TODO
  # make encrypted file

  # mount to /mnt/encrypted/

  # move all from app-data
  sudo mv /home/store/app-data /mnt/encrypted/
  # symlink
  sudo ln -s /mnt/encrypted/app-data /home/store/
}

function downloadSnapShot() {

  if [ $# -eq 0 ] || [ "$1" = "pruned.host4coins.net" ]; then
    hashFileName="sha256sum.txt"
    hashFileSigName="sha256sum.txt.asc"
    downloadDomain="pruned.host4coins.net/blocks"
    pgpKeyLink="https://keys.openpgp.org/vks/v1/by-fingerprint/440C15769D19E6908CC1DDB23070DE9772DB8A48"
  elif [ "$1" = "prunednode.today" ]; then
    hashFileName="latest.signed.txt"
    downloadDomain="prunednode.today"
    pgpKeyLink="https://stepansnigirev.com/ss-specter-release.asc"
  fi

  echo "# Check available diskspace"
  FREE=$(df -k --output=avail "$PWD" | tail -n1) # df -k not df -h
  if [ $FREE -lt 12582912 ]; then                # 12G = 12*1024*1024k
    echo "# The free space is only $FREE bytes!"
    echo "# Would need ~12GB free space to download and extract the snapshot."
    echo "# Press ENTER to continue to download regardless or CTRL+C to exit."
    read key
  else
    echo "# OK, more than 12GB is free!"
  fi
  sudo -u joinmarket mkdir /home/joinmarket/download 2>/dev/null
  cd /home/joinmarket/download || exit 1

  sudo rm $hashFileName 2>/dev/null
  echo "# Downloading $hashFileName ..."
  wget --prefer-family=ipv4 -O $hashFileName https://$downloadDomain/$hashFileName || exit 1

  downloadFileName=$(grep .zip <$hashFileName | awk '{print $2}')
  downloadLink="https://$downloadDomain/$downloadFileName"

  echo "# Import the signing key"
  curl -sS "$pgpKeyLink" | gpg --import || exit 1

  echo "# Verifying the signature of the hash ..."
  if [ ${#hashFileSigName} -gt 0 ]; then
    wget --prefer-family=ipv4 -O $hashFileSigName https://$downloadDomain/$hashFileSigName || exit 1
  fi
  if ! gpg --verify $hashFileSigName $hashFileName; then
    echo "# Invalid signature on $hashFileName"
    echo "# Press ENTER to remove the invalid file or CTRL+C to abort."
    read key
    echo "# Removing $hashFileName"
    rm -f $hashFileName
    exit 1
  fi

  if [ ! -f $downloadFileName ]; then
    echo
    echo "# Downloading $downloadLink ..."
    echo
    wget --prefer-family=ipv4 -O $downloadFileName $downloadLink || exit 1
  fi

  echo "# Verifying the hash (takes time) ..."
  if sha256sum -c $hashFileName --ignore-missing; then
    echo
    echo "# The PGP signature and the hash of the downloaded snapshot is correct"
  else
    echo
    echo "# Download failed --> the PGP signature did not match / signature(${goodSignature})"
    echo "# Press ENTER to remove the invalid files or CTRL+C to abort."
    read key
    echo "# Removing the downloaded files"
    rm -f $hashFileName
    rm -f $downloadFileName
    exit 1
  fi

  echo "# Extracting to /home/store/app-data/.bitcoin ..."
  FREE=$(df -k --output=avail "$PWD" | tail -n1) # df -k not df -h
  if [ $FREE -lt 7340032 ]; then                 # 7G = 7*1024*1024k
    echo "# The free space is only $FREE bytes!"
    echo "# Would need ~7GB free space to extract the snapshot."
    echo "# Press ENTER to continue to download regardless or CTRL+C to exit."
    read key
  else
    echo "# OK, more than 7GB is free!"
  fi
  addUserStore
  if [ ! -d /home/store/app-data/.bitcoin ]; then
    sudo mkdir -p /home/store/app-data/.bitcoin
  fi
  echo "# Making sure user: bitcoin exists"
  sudo adduser --system --group --shell /bin/bash --home /home/bitcoin bitcoin
  echo "Copy the skeleton files for login"
  sudo -u bitcoin cp -r /etc/skel/. /home/bitcoin/
  sudo chown -R bitcoin:bitcoin /home/store/app-data/.bitcoin
  echo "# Add the joinmarket user to the bitcoin group"
  sudo usermod -aG bitcoin joinmarket
  echo "# Make sure bitcoind is not running"
  sudo systemctl stop bitcoind
  if sudo -u bitcoin ls /home/bitcoin/.bitcoin/bitcoin.conf; then
    echo "# Back up bitcoin.conf"
    sudo -u bitcoin mv /home/bitcoin/.bitcoin/bitcoin.conf \
      /home/bitcoin/.bitcoin/bitcoin.conf.backup
  fi

  echo "# Clean old blocks and chainstate"
  sudo rm -rf /home/store/app-data/.bitcoin/blocks
  sudo rm -rf /home/store/app-data/.bitcoin/chainstate

  echo "# Unzip ..."
  sudo apt-get install -y unzip
  sudo -u bitcoin unzip -o $downloadFileName -d /home/store/app-data/.bitcoin
  if sudo -u bitcoin ls /home/bitcoin/.bitcoin/bitcoin.conf.backup; then
    echo "# Restore bitcoin.conf"
    sudo -u bitcoin mv -f /home/bitcoin/.bitcoin/bitcoin.conf.backup \
      /home/bitcoin/.bitcoin/bitcoin.conf
  fi
}

function installBitcoinCoreStandalone() {
  downloadBitcoinCore

  if [ -f /home/bitcoin/bitcoin/bitcoind ]; then
    installedVersion=$(/home/bitcoin/bitcoin/bitcoind --version | grep version)
    echo "${installedVersion} is already installed"
  else
    echo "# Adding the user: bitcoin"
    sudo adduser --system --group --shell /bin/bash --home /home/bitcoin bitcoin
    echo "Copy the skeleton files for login"
    sudo -u bitcoin cp -r /etc/skel/. /home/bitcoin/
    echo "# Add the joinmarket user to the bitcoin group"
    sudo usermod -aG bitcoin joinmarket
    echo "# Installing Bitcoin Core v${bitcoinVersion}"
    sudo -u bitcoin mkdir -p /home/bitcoin/bitcoin
    cd /home/joinmarket/download/bitcoin-${bitcoinVersion}/bin/ || exit 1
    sudo install -m 0755 -o root -g root -t /home/bitcoin/bitcoin ./*
  fi
  if [ "$(grep -c "/home/bitcoin/bitcoin" </etc/profile)" -eq 0 ]; then
    echo "# Add /home/bitcoin/bitcoin to global PATH"
    echo "PATH=/home/bitcoin/bitcoin:$PATH" | sudo tee -a /etc/profile
  fi
  if ! sudo -u bitcoin /home/bitcoin/bitcoin/bitcoind --version | grep "Bitcoin Core version"; then
    echo
    echo "# BUILD FAILED --> Was not able to install Bitcoin Core)"
    exit 1
  fi

  # bitcoin.conf
  if [ -f /home/store/app-data/.bitcoin/bitcoin.conf ]; then
    if [ $(sudo -u bitcoin grep -c rpcpassword </home/store/app-data/.bitcoin/bitcoin.conf) -eq 0 ]; then
      echo "# Removing old bitcoin.conf without rpcpassword configured"
      sudo rm /home/store/app-data/.bitcoin/bitcoin.conf
    fi
  fi

  echo "# symlink /home/store/app-data/.bitcoin to /home/bitcoin/"
  sudo rm -rf /home/bitcoin/.bitcoin # not a symlink, delete
  sudo mkdir -p /home/store/app-data/.bitcoin
  sudo ln -s /home/store/app-data/.bitcoin /home/bitcoin/

  if [ ! -f /home/bitcoin/.bitcoin/bitcoin.conf ]; then
    randomRPCpass=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c20)
    echo "
# bitcoind configuration for mainnet

# Connection settings
rpcuser=joininbox
rpcpassword="$randomRPCpass"

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
Environment='MALLOC_ARENA_MAX=1'
PIDFile=/home/bitcoin/bitcoin/bitcoind.pid
ExecStart=/home/bitcoin/bitcoin/bitcoind -daemon \\
            -pid=/home/bitcoin/bitcoin/bitcoind.pid
PermissionsStartOnly=true

# Process management
####################
Type=forking
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

# Directory creation and permissions
####################################
# Run as bitcoin:bitcoin
User=bitcoin
Group=bitcoin

StandardOutput=null
StandardError=journal

# Hardening measures
####################
# Provide a private /tmp and /var/tmp.
PrivateTmp=true
# Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full
# Deny access to /home, /root and /run/user
ProtectHome=true
# Disallow the process and all of its children to gain
# new privileges through execve().
NoNewPrivileges=true
# Use a new /dev namespace only populated with API pseudo devices
# such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true
# Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/bitcoind.service
  sudo systemctl daemon-reload
  sudo systemctl enable bitcoind
  echo "# OK - the bitcoind.service is now enabled"

  # add aliases
  if ! grep "alias bitcoin-cli" /home/joinmarket/_aliases.sh; then
    sudo bash -c "echo 'alias bitcoin-cli=\"sudo -u bitcoin /home/bitcoin/bitcoin/bitcoin-cli\"' >> /home/joinmarket/_aliases.sh"
  fi
  if ! grep "alias bitcoind" /home/joinmarket/_aliases.sh; then
    sudo bash -c "echo 'alias bitcoind=\"sudo -u bitcoin /home/bitcoin/bitcoin/bitcoind\"' >> /home/joinmarket/_aliases.sh"
  fi
  if ! grep "alias bitcoinlog" /home/joinmarket/_aliases.sh; then
    sudo bash -c "echo 'alias bitcoinlog=\"sudo tail -f /home/bitcoin/.bitcoin/debug.log\"' >> /home/joinmarket/_aliases.sh"
  fi
  if ! grep "alias bitcoinconf" /home/joinmarket/_aliases.sh; then
    sudo bash -c "echo 'alias bitcoinconf=\"sudo nano /home/bitcoin/.bitcoin/bitcoin.conf\"' >> /home/joinmarket/_aliases.sh"
  fi

  # set joinin.conf value
  /home/joinmarket/set.value.sh set network mainnet ${joininConfPath}

  sudo systemctl start bitcoind
  echo
  echo "# Installed $(sudo -u bitcoin /home/bitcoin/bitcoin/bitcoind --version | grep version)"
  echo
  echo "# Monitor the bitcoind with: sudo tail -f /home/bitcoin/.bitcoin/mainnet/debug.log"
  echo

  if [ ! -f /home/bitcoin/.bitcoin/mainnet/wallets/wallet.dat/wallet.dat ]; then
    echo "# Create wallet.dat ..."
    sleep 10
    sudo -u bitcoin /home/bitcoin/bitcoin/bitcoin-cli -named createwallet wallet_name=wallet.dat descriptors=false
  fi
}
