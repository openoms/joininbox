#!/bin/bash

/home/joinmarket/start.joininbox.sh
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=21
WIDTH=57
CHOICE_HEIGHT=13
BACKTITLE="JoininBox GUI $currentJBtag network:$network IP:$localip"
TITLE="JoininBox $currentJBtag $network"
MENU="
Choose from the options:"
OPTIONS=()

# Basic Options
OPTIONS+=(START   "Quickstart with JoinMarket")
if [ "${QTGUI}" != "without-qt"  ]; then
  OPTIONS+=(QTGUI   "Show how to open the JoinMarketQT GUI")
  HEIGHT=$((HEIGHT+1))
  CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
fi
OPTIONS+=("" ""
  WALLET  "Wallet management options"
  MAKER   "Yield Generator options"
  "" ""
  SEND    "Pay to an address with/without a coinjoin"
  FREEZE  "Exercise coin control within a mixdepth"
  PAYJOIN "Send/Receive between JoinMarket wallets"
  "" ""
  OFFERS  "Watch the Order Book locally"
  "" ""
  CONFIG "Connection and joinmarket.cfg settings" \
  TOOLS  "Extra helper functions and services")
  if [ "${runningEnv}" != mynode ]; then
    OPTIONS+=(UPDATE "Update JoininBox or JoinMarket")
    OPTIONS+=("" "")
    if [ "${runningEnv}" = raspiblitz ]; then
      OPTIONS+=(BLITZ "Switch to the RaspiBlitz menu")
      HEIGHT=$((HEIGHT+1))
      CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
    fi
    OPTIONS+=(REBOOT "Restart the computer")
    OPTIONS+=(SHUTDOWN "Switch off the computer")
    HEIGHT=$((HEIGHT+4))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT+4))
  fi

CHOICE=$(dialog \
          --clear \
          --backtitle "$BACKTITLE" \
          --title "$TITLE" \
          --ok-label "Select" \
          --cancel-label "Exit" \
          --menu "$MENU" \
            $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "${OPTIONS[@]}" \
            2>&1 >/dev/tty)

case $CHOICE in
  START)
    /home/joinmarket/menu.quickstart.sh
    waitKeyOnExit1 $?
    /home/joinmarket/menu.sh;;
  WALLET)
    /home/joinmarket/menu.wallet.sh
    waitKeyOnExit1 $?
    /home/joinmarket/menu.sh;;
  QTGUI)
    /home/joinmarket/info.qtgui.sh
    /home/joinmarket/menu.sh;;
  MAKER)
    /home/joinmarket/menu.yg.sh
    waitKeyOnExit1 $?
    /home/joinmarket/menu.sh;;
  SEND)
    /home/joinmarket/menu.send.sh
    echo ""
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/menu.sh;;
  FREEZE)
    /home/joinmarket/menu.freeze.sh
    echo ""
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/menu.sh;;
  PAYJOIN)
    /home/joinmarket/menu.payjoin.sh
    waitKeyOnExit1 $?
    /home/joinmarket/menu.sh;;
  OFFERS)
    /home/joinmarket/menu.orderbook.sh
    /home/joinmarket/menu.sh;;
  CONFIG)
    /home/joinmarket/menu.config.sh
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh;;
  TOOLS)
    /home/joinmarket/menu.tools.sh
    /home/joinmarket/menu.sh;;
  UPDATE)
    /home/joinmarket/menu.update.sh
    /home/joinmarket/menu.sh;;
  REBOOT)
    clear
    confirmation "Are you sure?" "Reboot" "Cancel" true 7 40
    confirmationReboot=$?
    if [ $confirmationReboot -eq 0 ]; then
        clear
        stopYG
        echo
        if [ "${runningEnv}" = raspiblitz ]; then
          sudo /home/admin/XXshutdown.sh reboot
          exit 0
        else
          echo "# Reboot"
          sudo shutdown now -r
        fi
    fi
    /home/joinmarket/menu.sh;;
  SHUTDOWN)
    clear
    confirmation "Are you sure?" "Shutdown" "Cancel" true 7 40
    confirmationShutdown=$?
    if [ $confirmationShutdown -eq 0 ]; then
      clear
      stopYG
      echo
      if [ "${runningEnv}" = raspiblitz ]; then
        sudo /home/admin/XXshutdown.sh
        exit 0
      else
        echo "# Shutdown"
        sudo shutdown now
      fi
    fi
    /home/joinmarket/menu.sh;;
  BLITZ)
    sudo su - admin;;
  *)
    clear
    echo "
***************************
* JoinMarket command line *
***************************
Notes on usage:
https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md

To open the JoininBox menu use: menu
To exit from the terminal type: exit
"
esac
