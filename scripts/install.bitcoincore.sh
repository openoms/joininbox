#!/bin/bash

source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

# check connectedRemoteNode var in joinin.conf
if ! grep -Eq "^connectedRemoteNode=" $joininConfPath; then
  echo "connectedRemoteNode=off" >>$joininConfPath
fi

if [ "$1" = "signetOn" ]; then
  installBitcoinCore
  installSignet
  sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh configure-local signet
  for state in "network=signet" "connectedRemoteNode=off" "RPCoverTor=off"; do
    key=${state%%=*}
    value=${state#*=}
    if ! grep -Eq "^${key}=" "$joininConfPath"; then
      echo "$key=$value" >>"$joininConfPath"
    else
      sed -i "s#^${key}=.*#${key}=${value}#g" "$joininConfPath"
    fi
  done

elif [ "$1" = "signetOff" ]; then
  removeSignetdService
  for state in "network=mainnet" "connectedRemoteNode=off" "RPCoverTor=off"; do
    key=${state%%=*}
    value=${state#*=}
    if ! grep -Eq "^${key}=" "$joininConfPath"; then
      echo "$key=$value" >>"$joininConfPath"
    else
      sed -i "s#^${key}=.*#${key}=${value}#g" "$joininConfPath"
    fi
  done
elif [ "$1" = "downloadCoreOnly" ]; then
  downloadBitcoinCore
fi
