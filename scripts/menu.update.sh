#!/bin/bash

source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=12
WIDTH=56
CHOICE_HEIGHT=3
TITLE="Update options"
MENU="
Current JoininBox version: $currentJBcommit
Current JoinMarket version: $currentJMversion"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(
  JOININBOX  "Update the JoininBox scripts and menu"
  JOINMARKET "Update/reinstall JoinMarket to $(grep testedJMversion= < ~/install.joinmarket.sh | cut -d '"' -f 2)"
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
      /home/joinmarket/install.joinmarket.sh update
      errorOnInstall $?
      echo
      echo "A new version might introduce new IRC servers and other settings."
      echo "It is best to reset the joinmarket.cfg after every install and can be done any time from the menu CONFIG -> RESET."
      read -p "Do you want to reset the joinmarket.cfg to the defaults (with Tor settings) now (yes/no)?" confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 0
      echo "# Removing the joinmarket.cfg"
      rm -f $JMcfgPath
      generateJMconfig
      if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
        read -p "Do you want to connect to the local Bitcoin Core on mainnet now (yes/no)?" confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 0
        connectLocalNode mainnet
        sudo systemctl start bitcoind
        showBitcoinLogs
      fi
      echo
      echo "Press ENTER to return to the menu"
      read key;;
  ADVANCED)
      /home/joinmarket/menu.update.advanced.sh;;
esac
