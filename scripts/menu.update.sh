#!/bin/bash

# functions

function updateJoininBox() {
echo "# removing the joininbox directory"
sudo rm -rf /home/joinmarket/joininbox
echo "# cloning the latest code from https://github.com/openoms/joininbox"
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git
echo "# copying the scripts in place"
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/*.* /home/joinmarket/
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
echo "# updated the JoininBox menu and scripts to the latest state in https://github.com/openoms/joininbox"
}

# BASIC MENU INFO
HEIGHT=10
WIDTH=55
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="Update options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JOININBOX "Update the JoininBox scripts and menu" \
  JOINMARKET "Update JoinMarket to $(cat install.joinmarket.sh | grep version= | cut -d '"' -f 2)" \
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
      ;;              
esac
