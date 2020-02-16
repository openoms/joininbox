#!/bin/bash

# Basic Options
OPTIONS=(LAN "Computers on the same network" \
        TOR "Copy from a Tor enabled remote node"
        )

CHOICE=$(dialog --clear --title "Would you like to copy over LAN or Tor?" --menu "" 11 60 6 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        LAN) echo "Copying over LAN";;
        TOR) echo "Copying over Tor";;
        *) exit 1;;
esac

if [ ! -f "/home/joinin/joinmarket-clientserver/jmvenv/bin/activate" ]; then
  dialog --title "JoinMarket is not installed" --yesno "Do you want to install Joinmarket now?" 8 60
  response=$?
  echo "response(${response})"
  if [ "${response}" = "1" ]; then
    echo "OK - starting JoinMarket installation"
    ./install.joinmarket.sh
    errorOnInstall=$?
    if [ ${errorOnInstall} -eq 0 ]; then
      dialog --title "Installed JoinMarket" \
        --msgbox "\nContinue from the menu or use the command line " 7 56
    else 
      DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
        --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
    fi
    menu
  fi
fi

if [ "${CHOICE}" = "LAN" ]; then
  # get local ip
  localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
elif [ "${CHOICE}" = "TOR" ]; then
  # set up a Hidden Service for ssh
  ./install.hiddenservice.sh ssh 22 22
  TOR_ADDRESS=$(sudo cat /var/lib/tor/$service/hostname)
fi

echo 
clear
echo "************************************************************************************"
echo "Instructions to COPY wallets from another computer"
echo "************************************************************************************"
echo ""
echo "You can use the wallets from another JoinMarket instance"
echo ""
echo "Both computers (your JoininBox and the other computer with the wallets) need"
echo "to be connected to the same local network."
echo ""
echo "Open a terminal on the source computer and change into the directory that contains the"
echo "wallets. You should see files called .jmdat'".
echo ""
echo "COPY, PASTE & EXECUTE the following command on the wallet source computer:"
if [ "${CHOICE}" = "LAN" ]; then
  echo "scp ./*.jmdat joinin@${localip}:/home/joinin/joinmarket-clientserver/scripts/wallets"
elif [ "${CHOICE}" = "TOR" ]; then
  echo "scp ./*.jmdat joinin@${TOR_ADDRESS}:/home/joinin/joinmarket-clientserver/scripts/wallets"
fi
echo "" 
echo "This command will ask for your SSH PASSWORD of your JoininBox."
echo "************************************************************************************"
echo "PRESS ENTER if the transfer is done OR if you want to choose another option."
sleep 2
read key