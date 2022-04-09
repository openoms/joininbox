#!/bin/bash

source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=16
WIDTH=60
CHOICE_HEIGHT=7
TITLE="Advanced update options"
MENU="
Current JoininBox version: $currentJBcommit
Current JoinMarket version: $currentJMversion"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JBCOMMIT "Update JoininBox to the latest commit"
  JBPR "Test a JoininBox pull request"
  JBRESET "Reinstall the JoininBox scripts and menu"
  JMCUSTOM "Update JoinMarket to a custom version"
  JMPR "Test a JoinMarket pull request"
  JMCOMMIT "Update JoinMarket to the latest commit"
  TOR "Update Tor to the latest alpha"
)

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
  JBRESET)
      updateJoininBox reset
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JBPR)
      echo
      read -p "Enter the number of the pull request to be tested: " PRnumber
      read -p "Continue to install the PR:
https://github.com/openoms/joininbox/pull/$PRnumber
(Y/N)? " confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 1
      updateJoininBox pr $PRnumber
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JBCOMMIT)
      updateJoininBox commit
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JMCUSTOM)
      clear
      echo
      read -p "Enter the version to be installed, eg 'v0.9.3': " updateVersion
      read -p "Continue to install the version:
https://github.com/JoinMarket-Org/joinmarket-clientserver/releases/tag/${updateVersion}
(Y/N)? " confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 1
      stopYG
      /home/joinmarket/install.joinmarket.sh -i update -v $updateVersion
      errorOnInstall $?
      echo
      menu_resetJMconfig
      if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
        menu_connectLocalCore
      fi
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JMPR)
      clear
      echo
      read -p "Enter the number of the pull request to be tested: " PRnumber
      read -p "Continue to install the PR:
https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/$PRnumber
(Y/N)? " confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 1
      stopYG
      /home/joinmarket/install.joinmarket.sh -i testPR -p $PRnumber
      errorOnInstall $?
      echo
      menu_resetJMconfig
      if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
        menu_connectLocalCore
      fi
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JMCOMMIT)
      /home/joinmarket/install.joinmarket.sh -p commit
      errorOnInstall $?
      echo
      menu_resetJMconfig
      if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
        menu_connectLocalCore
      fi
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  TOR)
      updateTor
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
esac
