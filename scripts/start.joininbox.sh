#!/bin/bash

echo "# starting JoininBox ..."

if [ ! -f /home/joinmarket/joinin.conf ]; then
  touch /home/joinmarket/joinin.conf
fi

source /home/joinmarket/_functions.sh

function ensureJoinMarketNG() {
  if [ ! -x /usr/local/libexec/joininbox/install.joinmarket-ng.sh ]; then
    sudo /home/joinmarket/install.joinmarket-ng.sh bootstrap
  fi
  if ! sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh status | grep -qx "isInstalled=1"; then
    sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh on
  fi
  sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh integrate
}

#############
# FIRST RUN #
#############

setupStepEntry=$(grep -c "setupStep" <$joininConfPath)
if [ "$setupStepEntry" -eq 0 ]; then
  echo "setupStep=0" >>$joininConfPath
fi

sourceConf /home/joinmarket/joinin.conf
if [ "$setupStep" -lt 100 ]; then
  if [ "$setupStep" -lt 5 ]; then
    # identify running env
    runningEnvEntry=$(grep -c "runningEnv" <$joininConfPath)
    if [ "$runningEnvEntry" -eq 0 ]; then
      if [ -f "/mnt/hdd/raspiblitz.conf" ] || [ -f "/mnt/hdd/app-data/raspiblitz.conf" ] ; then
        runningEnv="raspiblitz"
      elif [ -f "/usr/share/mynode/mynode_config.sh" ]; then
        runningEnv="mynode"
      else
        runningEnv="standalone"
      fi
      echo "runningEnv=$runningEnv" >>$joininConfPath
      sed -i "s#setupStep=.*#setupStep=1#g" $joininConfPath
    fi
    echo "# running in the environment: $runningEnv"

    # identify cpu architecture
    cpuEntry=$(grep -c "cpu" <$joininConfPath)
    if [ "$cpuEntry" -eq 0 ]; then
      cpu=$(uname -m)
      echo "cpu=$cpu" >>$joininConfPath
      sed -i "s#setupStep=.*#setupStep=2#g" $joininConfPath
    fi
    echo "# cpu=${cpu}"

    # check Tor
    torEntry=$(grep -c "runBehindTor" <$joininConfPath)
    if [ "$torEntry" -eq 0 ]; then
      torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
        https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
      if [ "$torTest" = "Congratulations. This browser is configured to use Tor." ]; then
        runBehindTor=on
      else
        runBehindTor=off
        echo
        echo "# WARNING: Tor is not functional"
        echo "# Press ENTER to continue without Tor or CTRL+C to cancel and try checking again with 'menu'"
        read key
      fi
      echo "runBehindTor=$runBehindTor" >>$joininConfPath
      echo "# runBehindTor=$runBehindTor"
    fi

    # make sure Tor path is known
    DirEntry=$(grep -c "HiddenServiceDir" <$joininConfPath)
    if [ "$DirEntry" -eq 0 ]; then
      if [ -d "/mnt/hdd/tor" ]; then
        HiddenServiceDir="/mnt/hdd/tor"
      else
        HiddenServiceDir="/var/lib/tor"
      fi
      echo "HiddenServiceDir=$HiddenServiceDir" >>$joininConfPath
      sed -i "s#setupStep=.*#setupStep=3#g" $joininConfPath
    fi

    # check for dialog
    if [ "$(dialog | grep -c "ComeOn Dialog!")" -eq 0 ]; then
      sudo apt-get install -y dialog
    fi
    # check for qrencode
    if [ "$(qrencode -V 2>&1 | grep -c "not found")" -gt 0 ]; then
      sudo apt-get install -y qrencode
    fi
    sed -i "s#setupStep=.*#setupStep=4#g" $joininConfPath

    # Install JoinMarket NG after Tor and first-run dependencies are prepared.
    ensureJoinMarketNG
    sed -i "s#setupStep=.*#setupStep=5#g" $joininConfPath
  fi
  # change the ssh password if standalone
  if [ "$runningEnv" = "standalone" ]; then
    sourceConf /home/joinmarket/joinin.conf
    if [ "$setupStep" -lt 6 ]; then
      # set ssh passwords on the first run
      sudo /home/joinmarket/set.password.sh
      sed -i "s#setupStep=.*#setupStep=6#g" $joininConfPath
    fi
    sourceConf /home/joinmarket/joinin.conf
    if [ "$setupStep" -lt 7 ] && [ ${cpu} != "x86_64" ]; then
      # expand SDcard partition on ARM
      sudo /home/joinmarket/standalone/expand.rootfs.sh
    fi
  fi
  sudo sed -i "s#setupStep=.*#setupStep=10#g" $joininConfPath
  sourceConf /home/joinmarket/joinin.conf
  if [ "$setupStep" -lt 11 ]; then
    if [ "$runningEnv" = "standalone" ]; then
      # open the config menu if standalone
      /home/joinmarket/menu.config.sh
    else
      # setup finished
      sudo sed -i "s#setupStep=.*#setupStep=100#g" $joininConfPath
    fi
  fi
fi

# Ensure upgrades from a completed legacy setup also install JoinMarket NG.
ensureJoinMarketNG

#############
# EVERY RUN #
#############

# Add default values to joinin.conf if needed.
if ! grep -Eq "^RPCoverTor=" $joininConfPath; then
  echo "RPCoverTor=off" >>$joininConfPath
fi
if ! grep -Eq "^network=" $joininConfPath; then
  echo "network=unknown" >>$joininConfPath
fi
if ! grep -Eq "^connectedRemoteNode=" $joininConfPath; then
  echo "connectedRemoteNode=off" >>$joininConfPath
fi

ngConfigPath="/home/joinmarketng/.joinmarket-ng/config.toml"
if [ -f "$ngConfigPath" ]; then
  IFS=$'\t' read -r ngNetwork ngRPCoverTor ngRemoteNode < <(python3 - "$ngConfigPath" <<'PYTHON'
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlsplit

try:
    config = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    network = config["network_config"]["network"]
    rpc_url = config["bitcoin"]["rpc_url"]
    host = urlsplit(rpc_url).hostname
    if network not in {"mainnet", "signet", "testnet"}:
        raise ValueError
    if host is None:
        raise ValueError
except (KeyError, OSError, TypeError, ValueError, tomllib.TOMLDecodeError):
    raise SystemExit(1)

host = host.lower()
rpc_over_tor = "on" if host.endswith(".onion") else "off"
remote_node = "off" if host in {"127.0.0.1", "::1", "localhost"} else "on"
print(f"{network}\t{rpc_over_tor}\t{remote_node}")
PYTHON
)
  if [ -n "$ngNetwork" ]; then
    sed -i "s#^network=.*#network=$ngNetwork#g" $joininConfPath
    sed -i "s#^RPCoverTor=.*#RPCoverTor=$ngRPCoverTor#g" $joininConfPath
    sed -i "s#^connectedRemoteNode=.*#connectedRemoteNode=$ngRemoteNode#g" $joininConfPath
  fi
fi

# add default value to joinin config if needed
if ! grep -Eq "^localip=" $joininConfPath; then
  echo "localip=unknown" >>$joininConfPath
fi
localip=$(hostname -I | awk '{print $1}')
sed -i "s#^localip=.*#localip=$localip#g" $joininConfPath
