#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/v1.6/home.admin/config.scripts/bonus.cryptoadvance-specter.sh
# https://github.com/cryptoadvance/specter-desktop  

pinnedVersion="1.3.1"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to switch Specter on, off or update"
 echo "tools.specter.sh [status|on|off|update]"
 echo "installing the version $pinnedVersion by default"
 exit 1
fi

echo "# install.specter.sh $1"

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

function createSpecterConfig() {
    echo "# Creating /home/specter/.specter/config.json"
    source /home/joinmarket/_functions.sh
    if [ "${runBehindTor}" = "on" ];then
      proxy="socks5h://localhost:9050"
      torOnly="true"
    else
      proxy=""
      torOnly="false"
    fi
    getRPC
    if [ $network = mainnet ];then
      dir="/home/bitcoin/.bitcoin"
    elif [ $network = signet ];then
      dir="/home/joinmarket/.bitcoin"
    elif [ $network = testnet ];then
      dir="/home/bitcoin/.bitcoin"
    fi
    cat > /home/joinmarket/config.json <<EOF
{
    "rpc": {
        "autodetect": false,
        "datadir": "$dir",
        "user": "$rpc_user",
        "password": "$rpc_pass",
        "port": "$rpc_port",
        "host": "$rpc_host",
        "protocol": "http"
    },
    "auth": "rpcpasswordaspin",
    "explorers": {
        "main": "",
        "test": "",
        "regtest": "",
        "signet": ""
    },
    "proxy_url": "$proxy",
    "only_tor": $torOnly,
    "tor_control_port": "",
    "hwi_bridge_url": "/hwi/api/",
    "uid": "",
    "unit": "btc",
    "price_check": false,
    "alt_rate": 1,
    "alt_symbol": "BTC",
    "price_provider": "",
    "validate_merkle_proofs": false
}
EOF
    sudo mv /home/joinmarket/config.json /home/specter/.specter/config.json
    sudo chown -R specter:specter /home/specter/.specter
}
if [ "$1" = "config" ]; then
  createSpecterConfig
fi

# get status key/values
if [ "$1" = "status" ]; then

  if [ "${specter}" = "on" ]; then

    echo "# configured=1"

    # get network info
    #localip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0|veth' | grep 'eth0\|wlan0\|enp0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    toraddress=$(sudo cat $HiddenServiceDir/specter/hostname 2>/dev/null)
    fingerprint=$(openssl x509 -in /home/specter/.specter/cert.pem -fingerprint -noout | cut -d"=" -f2)
    echo "localip='${localip}'"
    echo "toraddress='${toraddress}'"
    echo "fingerprint='${fingerprint}'"

    # check for error
    serviceFailed=$(sudo systemctl status specter | grep -c 'inactive (dead)')
    if [ "${serviceFailed}" = "1" ]; then
      echo "error='Service Failed'"
      exit 1
    fi

  else
    echo "configured=0"
  fi
  
  exit 0
fi

# show info menu
if [ "$1" = "menu" ]; then

  # get status
  echo "# Collecting status info ... (please wait)"
  source <(sudo /home/joinmarket/standalone/install.specter.sh status)

  echo "######################################"
  echo "# Specter Desktop connection details #"
  echo "######################################"
  echo
  echo "Open in your local web browser & accept the self-signed certificate:"
  echo "https://${localip}:25441"
  qrencode -t ANSIUTF8 "https://${localip}:25441"
  echo
  echo "SHA1 Thumb/Fingerprint:"
  echo "${fingerprint}"
  echo
  echo "Login with the password:"
  echo "$(jq -r '.rpc.password' /home/specter/.specter/config.json)"
  echo
  if [ "${runBehindTor}" = "on" ] && [ ${#toraddress} -gt 0 ]; then
    echo "Hidden Service address for the Tor Browser:"
    echo "https://${toraddress}"
    echo "Unfortunately the camera is currently not usable via Tor."
    qrencode -t ANSIUTF8 "https://${toraddress}"
  fi
  exit 0
fi

# add default value to config if needed
if ! grep -Eq "^specter=" /home/joinmarket/joinin.conf; then
  echo "specter=off" >> /home/joinmarket/joinin.conf
fi

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "# Install Specter Desktop"

    isInstalled=$(sudo ls /etc/systemd/system/specter.service 2>/dev/null | grep -c 'specter.service' || /bin/true)
  if [ ${isInstalled} -eq 0 ]; then

    echo "# Installing prerequisites"
    sudo apt update
    sudo apt install -y libusb-1.0.0-dev libudev-dev virtualenv libffi-dev

    addUserStore

    sudo adduser --disabled-password --gecos "" specter

    # store data with the store user
    sudo mkdir -p /home/store/app-data/.specter 2>/dev/null
    # symlink to specter user
    sudo chown -R specter:specter  /home/store/app-data/.specter
    sudo ln -s  /home/store/app-data/.specter /home/specter/ 2>/dev/null
    sudo chown -R specter:specter /home/specter/.specter

    # activating Authentication here ...
    createSpecterConfig

    echo "# Creating a virtualenv"
    sudo -u specter virtualenv --python=python3 /home/specter/.env

    echo "# pip-installing specter"
    sudo -u specter /home/specter/.env/bin/python3 -m pip install --upgrade cryptoadvance.specter==$pinnedVersion
    
    # Mandatory as the camera doesn't work without https
    echo "# Creating self-signed certificate"
    openssl req -x509 -newkey rsa:4096 -nodes -out /tmp/cert.pem -keyout /tmp/key.pem -days 365 -subj "/C=US/ST=Nooneknows/L=Springfield/O=Dis/CN=www.fakeurl.com"
    sudo mv /tmp/cert.pem /home/specter/.specter
    sudo chown -R specter:specter /home/specter/.specter/cert.pem
    sudo mv /tmp/key.pem /home/specter/.specter
    sudo chown -R specter:specter /home/specter/.specter/key.pem

    # open firewall
    echo "# Updating Firewall"
    sudo ufw allow 25441 comment 'specter'
    sudo ufw --force enable
    echo ""

    echo "# Installing udev-rules for hardware-wallets"
    
    # Ledger
    cat > /home/joinmarket/20-hw1.rules <<EOF
 HW.1 / Nano
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
# Blue
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0000|0000|0001|0002|0003|0004|0005|0006|0007|0008|0009|000a|000b|000c|000d|000e|000f|0010|0011|0012|0013|0014|0015|0016|0017|0018|0019|001a|001b|001c|001d|001e|001f", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
# Nano S
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001|1000|1001|1002|1003|1004|1005|1006|1007|1008|1009|100a|100b|100c|100d|100e|100f|1010|1011|1012|1013|1014|1015|1016|1017|1018|1019|101a|101b|101c|101d|101e|101f", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
# Aramis
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0002|2000|2001|2002|2003|2004|2005|2006|2007|2008|2009|200a|200b|200c|200d|200e|200f|2010|2011|2012|2013|2014|2015|2016|2017|2018|2019|201a|201b|201c|201d|201e|201f", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
# HW2
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0003|3000|3001|3002|3003|3004|3005|3006|3007|3008|3009|300a|300b|300c|300d|300e|300f|3010|3011|3012|3013|3014|3015|3016|3017|3018|3019|301a|301b|301c|301d|301e|301f", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
# Nano X
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004|4000|4001|4002|4003|4004|4005|4006|4007|4008|4009|400a|400b|400c|400d|400e|400f|4010|4011|4012|4013|4014|4015|4016|4017|4018|4019|401a|401b|401c|401d|401e|401f", TAG+="uaccess", TAG+="udev-acl", OWNER="specter"
EOF
    
    # ColdCard
    cat > /home/joinmarket/51-coinkite.rules <<EOF
# Linux udev support file.
#
# This is a example udev file for HIDAPI devices which changes the permissions
# to 0666 (world readable/writable) for a specific device on Linux systems.
#
# - Copy this file into /etc/udev/rules.d and unplug and re-plug your Coldcard.
# - Udev does not have to be restarted.
#

# probably not needed:
SUBSYSTEMS=="usb", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666"

# required:
# from <https://github.com/signal11/hidapi/blob/master/udev/99-hid.rules>
KERNEL=="hidraw*", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666"
EOF
    
    # Trezor
    cat > /home/joinmarket/51-trezor.rules <<EOF
# Trezor: The Original Hardware Wallet
# https://trezor.io/
#
# Put this file into /etc/udev/rules.d
#
# If you are creating a distribution package,
# put this into /usr/lib/udev/rules.d or /lib/udev/rules.d
# depending on your distribution

# Trezor
SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Trezor v2
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
EOF
    
    # KeepKey
    cat > /home/joinmarket/51-usb-keepkey.rules <<EOF
# KeepKey: Your Private Bitcoin Vault
# http://www.keepkey.com/
# Put this file into /usr/lib/udev/rules.d or /etc/udev/rules.d

# KeepKey HID Firmware/Bootloader
SUBSYSTEM=="usb", ATTR{idVendor}=="2b24", ATTR{idProduct}=="0001", MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="keepkey%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="2b24", ATTRS{idProduct}=="0001",  MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# KeepKey WebUSB Firmware/Bootloader
SUBSYSTEM=="usb", ATTR{idVendor}=="2b24", ATTR{idProduct}=="0002", MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="keepkey%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="2b24", ATTRS{idProduct}=="0002",  MODE="0666", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
EOF

    sudo mv /home/joinmarket/20-hw1.rules /home/joinmarket/51-coinkite.rules /home/joinmarket/51-trezor.rules /home/joinmarket/51-usb-keepkey.rules /etc/udev/rules.d/
    sudo chown root:root /etc/udev/rules.d/*
    sudo udevadm trigger
    sudo udevadm control --reload-rules
    sudo groupadd plugdev || /bin/true
    sudo usermod -aG plugdev bitcoin
    sudo usermod -aG plugdev specter

    # install service
    echo "# Install specter systemd service"
    cat > /home/joinmarket/specter.service <<EOF
# systemd unit for Cryptoadvance Specter

[Unit]
Description=specter
Wants=${network}d.service
After=${network}d.service

[Service]
ExecStart=/home/specter/.env/bin/python3 -m cryptoadvance.specter server --host 0.0.0.0 --cert=/home/specter/.specter/cert.pem --key=/home/specter/.specter/key.pem
User=specter
Environment=PATH=/home/specter/.specter.env/bin:/home/specter/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/sbin:/bin
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /home/joinmarket/specter.service /etc/systemd/system/specter.service
    sudo systemctl enable specter
    echo "# OK - the specter service is now enabled and started"
  else 
    echo "# specter already installed."
    createSpecterConfig
  fi

  # setting value in  config
  sudo sed -i "s/^specter=.*/specter=on/g" /home/joinmarket/joinin.conf
  
  # Hidden Service for SERVICE if Tor is active
  source /home/joinmarket/joinin.conf
  if [ "${runBehindTor}" = "on" ]; then
    # make sure to keep in sync with internet.tor.sh script
    # port 25441 is HTTPS with self-signed cert - specter only makes sense to be served over HTTPS
    /home/joinmarket/install.hiddenservice.sh specter 443 25441
  fi

  sudo systemctl start specter
  /home/joinmarket/standalone/install.specter.sh menu
  exit 0
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  # setting value in  config
  sudo sed -i "s/^specter=.*/specter=off/g" /home/joinmarket/joinin.conf

  # Hidden Service if Tor is active
  if [ "${runBehindTor}" = "on" ]; then
    /home/joinmarket/install.hiddenservice.sh off specter
  fi

  isInstalled=$(sudo ls /etc/systemd/system/specter.service 2>/dev/null | grep -c 'specter.service')
  if [ ${isInstalled} -eq 1 ]; then

    echo "# Removing Specter Desktop"
    sudo systemctl stop specter
    sudo systemctl disable specter
    sudo rm /etc/systemd/system/specter.service
    sudo -u specter /home/specter/.env/bin/python3 -m pip uninstall --yes cryptoadvance.specter

    if whiptail --defaultno --yesno "Do you want to delete all Data related to specter? This includes also Bitcoin-Core-Wallets managed by specter?" 0 0; then
      echo "# Removing wallets in core"
      customRPC "#listwallets" "listwallets" | tail -n +2
      for i in $(customRPC "#listwallets" "listwallets" | tail -n +2) 
      do  
	      name=$(echo $i | cut -d"/" -f2)
       	customRPC "#unloadwallet" "unloadwallet" "specter/$name"
      done
      echo "# Removing the  /home/store/app-data/.specter"
      sudo rm -rf  /home/store/app-data/.specter
      echo "# Removing the specter user and home directory "
      sudo userdel -rf specter
    else
      echo "# Removing the specter user and home directory"
      echo "# /home/store/app-data/.specter is preserved"
      sudo userdel -rf specter
    fi

    echo "# OK Specter removed."
  else 
    echo "# Specter is not installed."
  fi
  exit 0
fi

# update
if [ "$1" = "update" ]; then
  echo "# Updating Specter"
  sudo -u specter /home/specter/.env/bin/python3 -m pip install --upgrade cryptoadvance.specter
  echo "# Updated to the latest in https://pypi.org/project/cryptoadvance.specter/#history"
  echo "# Restarting the specter.service"
  sudo systemctl restart specter
  exit 0
fi

echo "# error='unknown parameter'"
exit 1
