#!/bin/bash

# sudo apt install dialog

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
  REPORT "Show report"
  OBWATCH "Show the offer book"
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
        UP_JIB
            ;;
esac