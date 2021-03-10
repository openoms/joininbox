#!/bin/bash

echo "# starting JoininBox ..."

if [ ! -f /home/joinmarket/joinin.conf ];then
  touch /home/joinmarket/joinin.conf
fi

source /home/joinmarket/_functions.sh

#############
# FIRST RUN #
#############

setupStepEntry=$(grep -c "setupStep" < $joininConfPath)
if [ "$setupStepEntry" -eq 0 ];then
  echo "setupStep=0" >> $joininConfPath
fi

source /home/joinmarket/joinin.conf
if [ "$setupStep" -lt 100 ];then
  if [ "$setupStep" -lt 5 ];then
    # identify running env
    runningEnvEntry=$(grep -c "runningEnv" < $joininConfPath)  
    if [ "$runningEnvEntry" -eq 0 ];then  
      if [ -f "/mnt/hdd/raspiblitz.conf" ];then
        runningEnv="raspiblitz"
      else
        runningEnv="standalone"
      fi
      echo "runningEnv=$runningEnv" >> $joininConfPath
      sed -i  "s#setupStep=.*#setupStep=1#g" $joininConfPath
    fi
    echo "# running in the environment: $runningEnv"
  
    # identify cpu architecture
    cpuEntry=$(grep -c "cpu" < $joininConfPath)
    if [ "$cpuEntry" -eq 0 ];then
      cpu=$(uname -m)
      echo "cpu=$cpu" >> $joininConfPath
      sed -i  "s#setupStep=.*#setupStep=2#g" $joininConfPath
    fi
    echo "# cpu=${cpu}"
  
    # check Tor
    torEntry=$(grep -c "runBehindTor" < $joininConfPath)
    if [ "$torEntry" -eq 0 ];then
      torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
      https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
      if [ "$torTest" = "Congratulations. This browser is configured to use Tor." ]
      then
        runBehindTor=on
      else
        runBehindTor=off
        echo
        echo "# WARNING: Tor is not functional"
        echo "# Press ENTER to continue without Tor or CTRL+C to cancel and try checking again with 'menu'"
        read key
      fi
      echo "runBehindTor=$runBehindTor" >> $joininConfPath
      echo "# runBehindTor=$runBehindTor"
    fi
  
    # make sure Tor path is known
    DirEntry=$(grep -c "HiddenServiceDir" < $joininConfPath)
    if [ "$DirEntry" -eq 0 ];then
      if [ -d "/mnt/hdd/tor" ];then
        HiddenServiceDir="/mnt/hdd/tor"
      else
        HiddenServiceDir="/var/lib/tor"
      fi  
      echo "HiddenServiceDir=$HiddenServiceDir" >> $joininConfPath
      sed -i  "s#setupStep=.*#setupStep=3#g" $joininConfPath
    fi

    # check for dialog
    if [ "$(dialog | grep -c "ComeOn Dialog!")" -eq 0 ];then
      sudo apt install -y dialog
      sed -i  "s#setupStep=.*#setupStep=4#g" $joininConfPath
    fi

    # check if JoinMarket is installed
    /home/joinmarket/install.joinmarket.sh install
    sed -i  "s#setupStep=.*#setupStep=5#g" $joininConfPath
  fi
  # change the ssh password if standalone
  if [ "$runningEnv" = "standalone" ];then
    source /home/joinmarket/joinin.conf
    if [ "$setupStep" -lt 6 ];then
      # set ssh passwords on the first run
      sudo /home/joinmarket/set.password.sh
      sed -i  "s#setupStep=.*#setupStep=6#g" $joininConfPath
    fi
    source /home/joinmarket/joinin.conf
    if [ "$setupStep" -lt 7 ]&&[ ${cpu} != "x86_64" ];then
      # expand SDcard partition on ARM
      sudo /home/joinmarket/standalone/expand.rootfs.sh
    fi
  fi
  generateJMconfig
  # setup finished
  sudo sed -i  "s#setupStep=.*#setupStep=100#g" $joininConfPath
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
if ! grep -Eq "^RPCoverTor=" $joininConfPath;then
  echo "RPCoverTor=off" >> $joininConfPath
fi
# check if bitcoin RPC connection is over Tor
if grep -Eq "^rpc_host = .*.onion" $JMcfgPath;then 
  echo "# RPC over Tor is on"
  sed -i "s/^RPCoverTor=.*/RPCoverTor=on/g" $joininConfPath
else
  echo "# RPC over Tor is off"
  sed -i "s/^RPCoverTor=.*/RPCoverTor=off/g" $joininConfPath
fi

# check if there is only one joinmarket wallet and make default
# add default value to joinin config if needed
if ! grep -Eq "^defaultWallet=" $joininConfPath;then
  echo "defaultWallet=off" >> $joininConfPath
fi
if [ "$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -cv /)" -gt 1 ];then
  echo "# Found more than one wallet file"
  echo "# Setting defaultWallet to off"
  sed -i "s#^defaultWallet=.*#defaultWallet=off#g" $joininConfPath
elif [ "$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -cv /)" -eq 1 ];then
  onlyWallet=$(ls -p /home/joinmarket/.joinmarket/wallets/ | grep -v /)
  echo "# Found only one wallet file: $onlyWallet"
  echo "# Using it as default"
  sed -i "s#^defaultWallet=.*#defaultWallet=$onlyWallet#g" $joininConfPath
fi

# add default value to joinin config if needed
if ! grep -Eq "^network=" $joininConfPath;then
  echo "network=unknown" >> $joininConfPath
fi
isMainnet=$(grep -c "network = mainnet" < $JMcfgPath)
isSignet=$(grep -c "network = signet" < $JMcfgPath)
isTestnet=$(grep -c "network = testnet" < $JMcfgPath)
if [ $isMainnet -gt 0 ];then
  sed -i "s#^network=.*#network=mainnet#g" $joininConfPath
elif [ $isSignet -gt 0 ];then
  sed -i "s#^network=.*#network=signet#g" $joininConfPath
elif [ $isTestnet -gt 0 ];then
  sed -i "s#^network=.*#network=testnet#g" $joininConfPath
else
  sed -i "s#^network=.*#network=unknown#g" $joininConfPath
fi

# add default value to joinin config if needed
if ! grep -Eq "^localip=" $joininConfPath;then
  echo "localip=unknown" >> $joininConfPath
fi
localip=$(ip addr | grep 'state UP' -A2 | grep -Ev 'docker0|veth' | \
grep 'eth0\|wlan0\|enp0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
sed -i "s#^localip=.*#localip=$localip#g" $joininConfPath

# check for qrencode
if [ "$(qrencode -V 2>&1 | grep -c "not found")" -gt 0 ];then
  sudo apt install -y qrencode
fi