#!/bin/bash

source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

if [ ${#network} -eq 0 ] || [ "${network}" = "unknown" ] ;then
  if [ "${runningEnv}" = standalone ]; then
    source /home/joinmarket/standalone/_functions.standalone.sh
    network=mainnet
  elif [ "${runningEnv}" = mynode ];then
    network=mainnet
  elif [ "${runningEnv}" = raspiblitz ];then
    if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
      sourceConf /mnt/hdd/raspiblitz.conf
    else
      sourceConf /mnt/hdd/app-data/raspiblitz.conf
    fi
    if [ $network = bitcoin ];then
      network=${chain}net
    else
      network=unsupported
    fi
  fi
fi

if [ "$runningEnv" = "standalone" ] && [ "$setupStep" -lt 100 ]; then
  echo "# Open the startup menu on the first start"
  sudo sed -i  "s#setupStep=.*#setupStep=100#g" $joininConfPath

  # BASIC MENU INFO
  HEIGHT=16
  WIDTH=68
  CHOICE_HEIGHT=24
  TITLE="Startup options"
  MENU="
  Welcome to JoininBox $currentJBcommit
  Choose from the options:"
  OPTIONS=()
  BACKTITLE="JoininBox GUI"
  CANCELLABEL="Main menu"

  OPTIONS+=(
      CONNECT "Connect to a remote bitcoin node on mainnet"
      SIGNET  "Start on signet with a local Bitcoin Core"
      PRUNED  "Start a pruned node from pruned.host4coins.net/blocks")
  if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
    OPTIONS+=(
      LOCAL   "Connect to the local Bitcoin Core on mainnet")
    HEIGHT=$((HEIGHT+1))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
  fi
  if [ -f /home/joinmarketng/.joinmarket-ng/config.toml ]; then
    OPTIONS+=("" "" NGCONF "Edit the JoinMarket NG configuration")
  fi
  OPTIONS+=("" "" UPDATE "Update JoininBox or JoinMarket NG")

else
  # BASIC MENU INFO
  HEIGHT=12
  WIDTH=68
  CHOICE_HEIGHT=20
  TITLE="Configuration options"
  MENU=""
  OPTIONS=()
  BACKTITLE="JoininBox GUI"
  CANCELLABEL="Back"

  # Basic Options
  if [ -f /home/joinmarketng/.joinmarket-ng/config.toml ]; then
    OPTIONS+=(NGCONF "Edit the JoinMarket NG configuration" "" "")
  fi
  OPTIONS+=(
       CONNECT  "Connect to a remote bitcoin node on mainnet"
      SIGNET   "Switch to signet with a local Bitcoin Core")
  if [ "${runningEnv}" = standalone ]; then
    OPTIONS+=(
      PRUNED   "Start a pruned node from pruned.host4coins.net/blocks")
    HEIGHT=$((HEIGHT+1))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
  fi
  if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
    OPTIONS+=(
      LOCAL    "Connect to the local Bitcoin Core on mainnet"
      "" ""
      BTCCONF  "Edit the local bitcoin.conf")
    HEIGHT=$((HEIGHT+3))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT+3))
  fi

fi

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "$CANCELLABEL" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  NGCONF)
    if sudo /home/joinmarket/set.conf.sh "/home/joinmarketng/.joinmarket-ng/config.toml" "joinmarketng"; then
      sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh sync-config
    fi
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh;;
  CONNECT)
    /home/joinmarket/install.bitcoincore.sh signetOff
    /home/joinmarket/menu.bitcoinrpc.sh
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  SIGNET)
    /home/joinmarket/install.bitcoincore.sh signetOn
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  PRUNED)
    installBitcoinCoreStandalone
    echo
    downloadSnapShot
    installMainnet
    showBitcoinLogs
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  LOCAL)
    connectLocalNode mainnet
    sudo systemctl start bitcoind
    showBitcoinLogs
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  BTCCONF)
    if [ ${#network} -eq 0 ] || [ ${network} = "mainnet" ] || [ "${runningEnv}" = "raspiblitz" ]; then
      bitcoinUser="bitcoin"
    elif [ ${network} = "signet" ]; then
      bitcoinUser="joinmarket"
    fi
    if /home/joinmarket/set.conf.sh "/home/${bitcoinUser}/.bitcoin/bitcoin.conf" "${bitcoinUser}"
    then
      echo "# Restarting bitcoind"
      sudo systemctl restart bitcoind
      sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh configure-local "$network"
      showBitcoinLogs
    else
      echo "# No change made"
    fi;;
  UPDATE)
      /home/joinmarket/menu.update.sh
      /home/joinmarket/menu.sh;;
esac
