#!/bin/bash

# WALLET menu options

source /home/joinmarket/joinin.conf
source /home/joinmarket/menu.functions.sh

# BASIC MENU INFO
HEIGHT=13
WIDTH=52
CHOICE_HEIGHT=20
TITLE="JoininBox"
BACKTITLE="JoininBox - Wallet management options"
MENU="
Wallet management options:"
OPTIONS=()

# Basic Options
OPTIONS+=(\
  GEN "Generate a new wallet" \
  HISTORY "Show all past transactions" \
  IMPORT "Copy wallet(s) from a remote node"\
  RECOVER "Restore a wallet from the seed" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in

  GEN)
      clear
      echo ""
      . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
      if [ ${RPCoverTor} = "on" ]; then 
        torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
      else
        python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
      fi
      echo "Press ENTER to return to the menu"
      read key
      ;;
  HISTORY)
      # wallet
      chooseWallet
      /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) history
      echo ""
      echo "Press ENTER to return to the menu"
      read key
      ;;
  IMPORT) 
      /home/joinmarket/info.importwallet.sh
      echo "Returning to the menu..."
      sleep 2
      /home/joinmarket/menu.sh
      ;;
  RECOVER)
      echo ""
      . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
      if [ ${RPCoverTor} = "on" ];then 
        torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
      else
        python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
      fi
      echo "Press ENTER to return to the menu"
      read key
      ;;
esac