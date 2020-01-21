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
OPTIONS+=(INSTALL "Install JoinMarket" \
  "" ""
  GEN "Generate a wallet" \
  INFO "Wallet information" \
  CONF "Configure Joinmarket" \
  "" ""
  PAY "Pay with a coinjoin" \
  TUMBLER "Run the Tumbler" \
  EMPTY "Empty a mixdepth" \
  "" ""
  CONF_YG "Configure the Yield Generator" \
  YG "Run the Yield Generator" \
  STOP "Stop the Yield Generator" \
  REPORT "Show report" \
  OBWATCH "Show the offer book" \
  "" ""
  RESTORE "Restore a wallet" \
  UP_JM "Update JoinMarket" \
  UP_JIB "Update JoininBox" 
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)


case $CHOICE in
        INSTALL)

            ;;
        GEN)
            ;;
        INFO)
            ./getpw.sh
            source joinin.conf
            clear
            echo "Decrypting the wallet $wallet . . ."
            python scriptstarter.py wallet-tool.py $wallet
            ;;
        CONF)

            ;;
        PAY)

            ;;
        TUMBLER)

            ;;
        EMPTY)
            ;;
        CONF_YG)

            ;;
        YG)
            ./getpw.sh
            source joinin.conf
            python scriptstarter.py yg-privacyenhanced.py $wallet
            ;;
        STOP)
            ;;
        REPORT)
            ;;
        OBWATCH)
            ;;
        RESTORE)
            ;;
        UP_JM)
            ;;
        UP_JIB)
            ;;
esac
