#!/bin/bash

source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=8
WIDTH=55
CHOICE_HEIGHT=2
TITLE="Update options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JOININBOX "Update the JoininBox scripts and menu" \
  JOINMARKET "Update JoinMarket to $(grep version= < install.joinmarket.sh | cut -d '"' -f 2)" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  JOININBOX)
      updateJoininBox
      echo ""
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JOINMARKET)
      /home/joinmarket/install.joinmarket.sh update
      echo ""
      echo "Press ENTER to return to the menu"
      read key
      ;;              
esac
