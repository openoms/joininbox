#!/bin/bash

echo "# starting JoininBox ..."

if [ ! -f /home/joinmarket/joinin.conf ];then
  touch /home/joinmarket/joinin.conf
fi

source /home/joinmarket/_functions.sh

#############
# FIRST RUN #
#############

setupStepEntry=$(grep -c "setupStep" < /home/joinmarket/joinin.conf)
if [ "$setupStepEntry" -eq 0 ];then
  echo "setupStep=0" >> /home/joinmarket/joinin.conf
fi

source /home/joinmarket/joinin.conf
if [ "$setupStep" -lt 100 ];then
  
  # identify running env
  runningEnvEntry=$(grep -c "runningEnv" < /home/joinmarket/joinin.conf)  
  if [ "$runningEnvEntry" -eq 0 ];then  
    if [ -f "/mnt/hdd/raspiblitz.conf" ];then
      runningEnv="raspiblitz"
    else
      runningEnv="standalone"
    fi
    echo "runningEnv=$runningEnv" >> /home/joinmarket/joinin.conf
    sed -i  "s#setupStep=.*#setupStep=1#g" /home/joinmarket/joinin.conf
  fi
  echo "# running in the environment: $runningEnv"

  # identify cpu architecture
  cpuEntry=$(grep -c "cpu" < /home/joinmarket/joinin.conf)
  if [ "$cpuEntry" -eq 0 ];then
    cpu=$(uname -m)
    echo "cpu=$cpu" >> /home/joinmarket/joinin.conf
    sed -i  "s#setupStep=.*#setupStep=2#g" /home/joinmarket/joinin.conf
  fi
  echo "# cpu=${cpu}"

  # check Tor
  torEntry=$(grep -c "runBehindTor" < /home/joinmarket/joinin.conf)
  if [ "$torEntry" -eq 0 ];then
    torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
    https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
    if [ "$torTest" = "Congratulations. This browser is configured to use Tor." ]
    then
      runBehindTor=on
    else
      runBehindTor=off
    fi
    echo "runBehindTor=$runBehindTor" >> /home/joinmarket/joinin.conf
    echo "# runBehindTor=$runBehindTor"
  fi

  # make sure Tor path is known
  DirEntry=$(grep -c "HiddenServiceDir" < /home/joinmarket/joinin.conf)
  if [ "$DirEntry" -eq 0 ];then
    if [ -d "/mnt/hdd/tor" ];then
      HiddenServiceDir="/mnt/hdd/tor"
    else
      HiddenServiceDir="/var/lib/tor"
    fi  
    echo "HiddenServiceDir=$HiddenServiceDir" >> /home/joinmarket/joinin.conf
    sed -i  "s#setupStep=.*#setupStep=3#g" /home/joinmarket/joinin.conf
  fi

  # check for dialog
  if [ "$(dialog | grep -c "ComeOn Dialog!")" -eq 0 ];then
    sudo apt install dialog
    sed -i  "s#setupStep=.*#setupStep=4#g" /home/joinmarket/joinin.conf
  fi

  # check if JoinMarket is installed
  /home/joinmarket/install.joinmarket.sh install
  sed -i  "s#setupStep=.*#setupStep=5#g" /home/joinmarket/joinin.conf

  # change the ssh password if standalone
  if [ "$runningEnv" = "standalone" ];then
    # set ssh passwords on the first run
    sudo /home/joinmarket/set.password.sh
    sed -i  "s#setupStep=.*#setupStep=6#g" /home/joinmarket/joinin.conf
    # expand SDcard partition on ARM
    if [ ${cpu} != "x86_64" ]; then
      sudo /home/joinmarket/standalone/expand.rootfs.sh
      sed -i  "s#setupStep=.*#setupStep=7#g" /home/joinmarket/joinin.conf
    fi
  fi
  generateJMconfig
  # setup finished
  sudo sed -i  "s#setupStep=.*#setupStep=100#g" /home/joinmarket/joinin.conf
  # open the config menu if standalone
  if [ "$runningEnv" = "standalone" ];then
    /home/joinmarket/menu.config.sh
  fi
fi

#############
# EVERY RUN #
#############

# check bitcoind RPC setting
# add default value to joinin config if needed
if ! grep -Eq "^RPCoverTor=" /home/joinmarket/joinin.conf;then
  echo "RPCoverTor=off" >> /home/joinmarket/joinin.conf
fi
# check if bitcoin RPC connection is over Tor
if grep -Eq "^rpc_host = .*.onion" /home/joinmarket/.joinmarket/joinmarket.cfg;then 
  echo "# RPC over Tor is on"
  sed -i "s/^RPCoverTor=.*/RPCoverTor=on/g" /home/joinmarket/joinin.conf
else
  echo "# RPC over Tor is off"
  sed -i "s/^RPCoverTor=.*/RPCoverTor=off/g" /home/joinmarket/joinin.conf
fi

# check if there is only one joinmarket wallet and make default
# add default value to joinin config if needed
if ! grep -Eq "^defaultWallet=" /home/joinmarket/joinin.conf;then
  echo "defaultWallet=off" >> /home/joinmarket/joinin.conf
fi
if [ "$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -cv /)" -gt 1 ];then
  echo "# Found more than one wallet file"
  echo "# Setting defaultWallet to off"
  sed -i "s#^defaultWallet=.*#defaultWallet=off#g" /home/joinmarket/joinin.conf
elif [ "$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -cv /)" -eq 1 ];then
  onlyWallet=$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -v /)
  echo "# Found only one wallet file: $onlyWallet"
  echo "# Using it as default"
  sed -i "s#^defaultWallet=.*#defaultWallet=$onlyWallet#g" /home/joinmarket/joinin.conf
fi

# add default value to joinin config if needed
if ! grep -Eq "^network=" /home/joinmarket/joinin.conf;then
  echo "network=unknown" >> /home/joinmarket/joinin.conf
fi
isMainnet=$(grep -c "network = mainnet" < /home/joinmarket/.joinmarket/joinmarket.cfg)
isSignet=$(grep -c "network = signet" < /home/joinmarket/.joinmarket/joinmarket.cfg)
isTestnet=$(grep -c "network = testnet" < /home/joinmarket/.joinmarket/joinmarket.cfg)
if [ $isMainnet -gt 0 ];then
  sed -i "s#^network=.*#network=mainnet#g" /home/joinmarket/joinin.conf
elif [ $isSignet -gt 0 ];then
  sed -i "s#^network=.*#network=signet#g" /home/joinmarket/joinin.conf
elif [ $isTestnet -gt 0 ];then
  sed -i "s#^network=.*#network=testnet#g" /home/joinmarket/joinin.conf
else
  sed -i "s#^network=.*#network=unknown#g" /home/joinmarket/joinin.conf
fi

# add default value to joinin config if needed
if ! grep -Eq "^localip=" /home/joinmarket/joinin.conf;then
  echo "localip=unknown" >> /home/joinmarket/joinin.conf
fi
localip=$(ip addr | grep 'state UP' -A2 | grep -Ev 'docker0|veth' | \
grep 'eth0\|wlan0\|enp0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
sed -i "s#^localip=.*#localip=$localip#g" /home/joinmarket/joinin.conf
