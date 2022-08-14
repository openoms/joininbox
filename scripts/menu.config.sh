#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

if [ ${#network} -eq 0 ] || [ "${network}" = "unknown" ] ;then
  if [ "${runningEnv}" = standalone ]; then
    source /home/joinmarket/standalone/_functions.standalone.sh
    network=mainnet
  elif [ "${runningEnv}" = mynode ];then
    network=mainnet
  elif [ "${runningEnv}" = raspiblitz ];then
    source /mnt/hdd/raspiblitz.conf
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
  WIDTH=64
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
      PRUNED  "Start a pruned node from prunednode.today")
  if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
    OPTIONS+=(
      LOCAL   "Connect to the local Bitcoin Core on mainnet")
    HEIGHT=$((HEIGHT+1))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
  fi
  OPTIONS+=(
      "" ""
      JMCONF  "Edit the joinmarket.cfg manually"
      "" ""
      UPDATE  "Update JoininBox or JoinMarket")

else
  # BASIC MENU INFO
  HEIGHT=12
  WIDTH=64
  CHOICE_HEIGHT=20
  TITLE="Configuration options"
  MENU=""
  OPTIONS=()
  BACKTITLE="JoininBox GUI"
  CANCELLABEL="Back"

  # Basic Options
  OPTIONS+=(
      JMCONF   "Edit the joinmarket.cfg manually"
      "" ""
      CONNECT  "Connect to a remote bitcoin node on mainnet"
      SIGNET   "Switch to signet with a local Bitcoin Core")
  if [ "${runningEnv}" = standalone ]; then
    OPTIONS+=(
      PRUNED   "Start a pruned node locally from prunednode.today")
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

  OPTIONS+=(
      "" ""
      RESET    "Reset the joinmarket.cfg to the defaults")
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
  JMCONF)
    /home/joinmarket/install.joinmarket.sh -i config
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh;;
  RESET)
    echo "# Removing the joinmarket.cfg"
    rm -f $JMcfgPath
    generateJMconfig
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  CONNECT)
    /home/joinmarket/install.bitcoincore.sh signetOff
    /home/joinmarket/menu.bitcoinrpc.sh
    # set joinin.conf value
    /home/joinmarket/set.value.sh set network mainnet ${joininConfPath}
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  SIGNET)
    if [ "${runningEnv}" = "raspiblitz" ] && grep "signet=on" /mnt/hdd/raspiblitz.conf; then
      echo "There is a signet instance running on the RaspiBlitz already."
      echo "Please connect manually by editing the joinmarket.cfg."
      echo "See: https://github.com/openoms/joininbox/issues/72"
    else
      /home/joinmarket/install.bitcoincore.sh signetOn
    fi
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  PRUNED)
    installBitcoinCoreStandalone
    echo
    downloadSnapShot
    installMainnet
    connectLocalNode
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
    if [ ${#network} -eq 0 ] || [ ${network} = "mainnet" ]; then
      bictoinUser="bitcoin"
    elif [ ${network} = "signet" ]; then
      bictoinUser="joinmarket"
    fi
    if /home/joinmarket/set.conf.sh "/home/${bictoinUser}/.bitcoin/bitcoin.conf" "${bictoinUser}"
    then
      echo "# Restarting bitcoind"
      sudo systemctl restart bitcoind
      showBitcoinLogs
    else
      echo "# No change made"
    fi;;
  UPDATE)
      /home/joinmarket/menu.update.sh
      /home/joinmarket/menu.sh;;
esac