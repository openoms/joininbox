source /home/joinmarket/_functions.sh

# add default value to config if needed
if ! grep -Eq "^specter=" $joininConfPath; then
  echo "specter=off" >> $joininConfPath
fi

source $joininConfPath

# BASIC MENU INFO
HEIGHT=10
WIDTH=55
CHOICE_HEIGHT=20
TITLE="Specter Desktop"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI $currentJBtag network:$network IP:$localip"

# Basic Options
OPTIONS+=(
    INSTALL "Install or reconfigure Specter Desktop")
if [ $specter = on ];then
  OPTIONS+=(
    INFO "Connection info and password"
    UPDATE "Update Specter Desktop"
    REMOVE "Uninstall Specter Desktop")
fi

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
  INSTALL)
    /home/joinmarket/standalone/install.specter.sh on
    echo
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/standalone/menu.specter.sh
    ;;
 INFO)
    /home/joinmarket/standalone/install.specter.sh menu
    echo
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/standalone/menu.specter.sh
    ;;
  UPDATE)
    /home/joinmarket/standalone/install.specter.sh update
    echo
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/standalone/menu.specter.sh
    ;;
  REMOVE)
    /home/joinmarket/standalone/install.specter.sh off
    echo
    echo "Press ENTER to return to the menu..."
    read key
    ;;
esac