#!/bin/bash

if [ $(dialog | grep -c "ComeOn Dialog!") -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f joinin.conf ]; then
  touch joinin.conf
fi
source joinin.conf

# cd ~/bin/joinmarket-clientserver && source jmvenv/bin/activate && cd scripts

# BASIC MENU INFO
HEIGHT=26
WIDTH=50
CHOICE_HEIGHT=19
BACKTITLE=""
TITLE="JoininBox"
MENU="Choose from the options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  INFO "Show the balance and addresses" \
  PAY "Pay with a coinjoin" \
  TUMBLER "Run the Tumbler" \
  YG "Run the Yield Generator" \
  "" ""
  HISTORY "Show the past transactions" \
  OBWATCH "Show the offer book" \
  EMPTY "Empty a mixdepth" \
  "" ""
  CONF "Configure Joinmarket" \
  CONF_YG "Configure the Yield Generator" \
  STOP "Stop the Yield Generator" \
  "" ""
  GEN "Generate a wallet" \
  RESTORE "Restore a wallet" \
  INSTALL "Install JoinMarket" \
  UP_JM "Update JoinMarket" \
  UP_JIB "Update JoininBox" \
)

CHOICE=$(DIALOGRC=.dialogrc.black-cyan dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)


case $CHOICE in

        INFO)
            ./getpw.sh
            source joinin.conf
            clear
            echo "Decrypting the wallet $wallet.jmdat . . ."
            echo ""
            echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
            . /home/joinin/joinmarket-clientserver/jmvenv/bin/activate
            python scriptstarter.py wallet-tool $wallet
            ;;
        PAY)
            ;;            
        TUMBLER)
            ;;
        YG)
            ./getpw.sh
            source joinin.conf
            ./servicemaker.sh yg-privacyenhanced $wallet
            # sudo systemctl status yg-privacyenhanced
            ./mainmenu.sh
            ;;
        HISTORY)
            ;;
        OBWATCH)
            ;;
        EMPTY)
            ;;
        CONF)
            ;;
        CONF_YG)
            ;;
        STOP)
            ;;
        GEN)
            ;;
        RESTORE)
            ;;
        INSTALL)
            ;;
        UP_JM)
            ;;
        UP_JIB)
            ;;
esac
