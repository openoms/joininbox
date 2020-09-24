#!/bin/bash

echo "# starting JoininBox ..."

if [ "$(dialog | grep -c "ComeOn Dialog!")" -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f /home/joinmarket/joinin.conf ]; then
  touch /home/joinmarket/joinin.conf
fi

# get settings on first run
runningEnv=$(grep -c "runningEnv" < /home/joinmarket/joinin.conf)
if [ "$runningEnv" -eq 0 ]; then
  if [ -f "/mnt/hdd/raspiblitz.conf" ] ; then
    runningEnv="raspiblitz"
    setupStep=100
  else
    runningEnv="standalone"
    setupStep=0
  fi  
  echo "runningEnv=$runningEnv" >> /home/joinmarket/joinin.conf
  echo "setupStep=$setupStep" >> /home/joinmarket/joinin.conf
  echo "# running in the environment: $runningEnv"

  # make sure Tor path is known
  checkDirEntry=$(grep -c "HiddenServiceDir" < /home/joinmarket/joinin.conf)
  if [ "$checkDirEntry" -eq 0 ]; then
    if [ -d "/mnt/hdd/tor" ] ; then
      HiddenServiceDir="/mnt/hdd/tor"
    else
      HiddenServiceDir="/var/lib/tor"
    fi  
  echo "HiddenServiceDir=$HiddenServiceDir" >> /home/joinmarket/joinin.conf
  fi
fi

source /home/joinmarket/joinin.conf

if [ "$runningEnv" = "standalone" ]; then
  if [ "$setupStep" = "0" ]; then
    # set ssh passwords on the first run
    /home/joinmarket/set.password.sh || exit 1
    sudo sed -i  "s#setupStep=.*#setupStep=100#g" /home/joinmarket/joinin.conf
  fi
elif [ "$runningEnv" = "raspiblitz" ]; then
  # check for the joinmarket.cfg
  if [ ! -f "/home/joinmarket/.joinmarket/joinmarket.cfg" ]; then
    echo " # generating the joinmarket.cfg"
    echo ""
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
    cd /home/joinmarket/joinmarket-clientserver/scripts/
    python wallet-tool.py generate --datadir=/home/joinmarket/.joinmarket
    sudo chmod 600 /home/joinmarket/.joinmarket/joinmarket.cfg || exit 1
    echo ""
    echo "# editing the joinmarket.cfg"
    sed -i "s/^rpc_user =.*/rpc_user = raspibolt/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    PASSWORD_B=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
    sed -i "s/^rpc_password =.*/rpc_password = $PASSWORD_B/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    echo "# filled the bitcoin RPC password (PASSWORD_B)"
    sed -i "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    echo "# using the bitcoind wallet: wallet.dat"
    #communicate with IRC servers via Tor
    sed -i "s/^host = irc.darkscience.net/#host = irc.darkscience.net/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#host = darksci3bfoka7tw.onion/host = darksci3bfoka7tw.onion/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^host = irc.hackint.org/#host = irc.hackint.org/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion/host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^socks5 = false/#socks5 = false/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#socks5 = true/socks5 = true/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#port = 6667/port = 6667/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#usessl = false/usessl = false/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    echo "# edited the joinmarket.cfg to communicate over Tor only"
  fi
fi