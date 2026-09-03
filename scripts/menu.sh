#!/bin/bash

/home/joinmarket/start.joininbox.sh
source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

# BASIC MENU INFO
HEIGHT=14
WIDTH=57
CHOICE_HEIGHT=6
BACKTITLE="JoininBox GUI $currentJBtag network:$network IP:$localip"
TITLE="JoininBox $currentJBtag $network"
MENU="
Choose from the options:"

# warn prominently on top of the menu if this is an unverified
# pull-request test image (labeled by build_joininbox.sh)
if [ -f /etc/joininbox-build-info ]; then
  pr_build=$(grep -E "^pr_build=" /etc/joininbox-build-info | cut -d= -f2)
  MENU="
!!! UNVERIFIED PR BUILD #${pr_build} - TESTING ONLY !!!
Choose from the options:"
  HEIGHT=$((HEIGHT + 1))
fi
OPTIONS=()

OPTIONS=(
  JOINMARKETNG "Open JoinMarket NG"
  CONFIG "Bitcoin and JoininBox settings"
  UPDATE "Update JoininBox or JoinMarket NG")
if [ "${runningEnv}" != mynode ]; then
  OPTIONS+=("" "")
  if [ "${runningEnv}" = raspiblitz ]; then
    OPTIONS+=(BLITZ "Switch to the RaspiBlitz menu")
    HEIGHT=$((HEIGHT + 1))
    CHOICE_HEIGHT=$((CHOICE_HEIGHT + 1))
  fi
  OPTIONS+=(REBOOT "Restart the computer")
  OPTIONS+=(SHUTDOWN "Switch off the computer")
  HEIGHT=$((HEIGHT + 4))
  CHOICE_HEIGHT=$((CHOICE_HEIGHT + 4))
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
JOINMARKETNG)
  sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh menu
  /home/joinmarket/menu.sh
  ;;
CONFIG)
  /home/joinmarket/menu.config.sh
  echo "Returning to the menu..."
  sleep 1
  /home/joinmarket/menu.sh
  ;;
UPDATE)
  /home/joinmarket/menu.update.sh
  /home/joinmarket/menu.sh
  ;;
REBOOT)
  clear
  confirmation "Are you sure?" "Reboot" "Cancel" true 7 40
  confirmationReboot=$?
  if [ $confirmationReboot -eq 0 ]; then
    clear
    echo
    if [ "${runningEnv}" = raspiblitz ]; then
      sudo /home/admin/config.scripts/blitz.shutdown.sh reboot
      exit 0
    else
      echo "# Reboot"
      sudo shutdown now -r
    fi
  fi
  /home/joinmarket/menu.sh
  ;;
SHUTDOWN)
  clear
  confirmation "Are you sure?" "Shutdown" "Cancel" true 7 40
  confirmationShutdown=$?
  if [ $confirmationShutdown -eq 0 ]; then
    clear
    echo
    if [ "${runningEnv}" = raspiblitz ]; then
      sudo /home/admin/config.scripts/blitz.shutdown.sh
      exit 0
    else
      echo "# Shutdown"
      sudo shutdown now
    fi
  fi
  /home/joinmarket/menu.sh
  ;;
BLITZ)
  sudo su - admin
  ;;
*)
  clear
  echo "
***************************
 * JoinMarket NG command line *
***************************
To open the JoininBox menu use: menu
To open JoinMarket NG use: jm-ng
To exit from the terminal type: exit
"
  ;;
esac
