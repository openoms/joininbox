#!/bin/bash

source /home/joinmarket/joinin.conf
source /mnt/hdd/raspiblitz.conf

# BASIC MENU INFO
HEIGHT=8
WIDTH=50
CHOICE_HEIGHT=3
TITLE="Jam - Joinmarket WebUI Options"
MENU="
Choose from the options:"
OPTIONS=()
if [ "${jam}" = on ]; then
  OPTIONS+=(INFO "Show how to open Jam")
  OPTIONS+=(UPDATE "Update Jam")
  OPTIONS+=(OFF "Uninstall Jam")
  HEIGHT=$((HEIGHT + 3))
  CHOICE_HEIGHT=$((CHOICE_HEIGHT + 3))
elif [ -z "${jam}" ] || [ "${jam}" = off ]; then
  OPTIONS+=(ON "Install Jam")
  HEIGHT=$((HEIGHT + 1))
  CHOICE_HEIGHT=$((CHOICE_HEIGHT + 1))
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
INFO)
  sudo -u admin /home/admin/config.scripts/bonus.jam.sh menu
  /home/joinmarket/menu.sh
  ;;
UPDATE)
  sudo -u admin /home/admin/config.scripts/bonus.jam.sh update
  /home/joinmarket/menu.sh
  ;;
OFF)
  sudo -u admin /home/admin/config.scripts/bonus.jam.sh off
  /home/joinmarket/menu.sh
  ;;
ON)
  sudo -u admin /home/admin/config.scripts/bonus.jam.sh on
  /home/joinmarket/menu.sh
  ;;
esac
