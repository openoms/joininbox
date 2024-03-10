#!/bin/bash

source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=15
WIDTH=57
CHOICE_HEIGHT=4
TITLE="Update options"
MENU="
Installed versions:
JoininBox $currentJBcommit
JoinMarket $currentJMversion
$currentBTCversion"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(
  JOININBOX  "Update the JoininBox scripts and menu"
  JOINMARKET "Update/reinstall JoinMarket to $(grep testedJMversion= < ~/install.joinmarket.sh | cut -d '"' -f 2)")

if [ "$runningEnv" = "standalone" ]; then
  OPTIONS+=(\
  BITCOIN   "Update Bitcoin Core to a chosen version")
fi
OPTIONS+=(\
  ADVANCED   "Advanced update options")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Back" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  JOININBOX)
      updateJoininBox
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key;;
  JOINMARKET)
      /home/joinmarket/install.joinmarket.sh -i update
      errorOnInstall $?
      echo
      menu_resetJMconfig
      if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
        menu_connectLocalCore
      fi
      echo
      echo "Press ENTER to return to the menu"
      read key;;
  BITCOIN)
      /home/joinmarket/standalone/bitcoin.update.sh custom
      errorOnInstall $?
      echo
      echo "# Start bitcoind .. "
      sudo systemctl start bitcoind
      echo "# Monitoring the bitcoind logs .. "
      showBitcoinLogs;;
  ADVANCED)
      /home/joinmarket/menu.update.advanced.sh;;
esac
