#!/bin/bash

source /home/joinmarket/_functions.sh

currentJBversion=$(cd $HOME/joininbox; git describe --tags)
currentJMversion=$(cd $HOME/joinmarket-clientserver; git describe --tags)

# BASIC MENU INFO
HEIGHT=11
WIDTH=56
CHOICE_HEIGHT=2
TITLE="Update options"
MENU="
Current JoininBox version: $currentJBversion
Current JoinMarket version: $currentJMversion"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JOININBOX "Update the JoininBox scripts and menu" \
  JOINMARKET "Update/reinstall JoinMarket to $(grep JMVersion= < ~/_functions.sh | cut -d '"' -f 2)" \
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
