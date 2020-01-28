#!/bin/bash

# get local ip
localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
echo $localip
# Basic Options
OPTIONS=(UNIX "MacOS or Linux" \
        WINDOWS "Windows"
        )

CHOICE=$(dialog --clear --title "Which System is running on the other computer?" --menu "" 11 60 6 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        UNIX) echo "Linus";;
        WINDOWS) echo "Bill";;
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
if [ "${CHOICE}" = "WINDOWS" ]; then
  echo "scp ./*.jmdat joinin@${localip}:/home/joinin/joinmarket-clientserver/scripts/wallets"
else
  echo "scp ./*.jmdat joinin@${localip}:/home/joinin/joinmarket-clientserver/scripts/wallets"
fi
echo "" 
echo "This command will ask for your SSH PASSWORD of your JoininBox."
echo "************************************************************************************"
echo "PRESS ENTER if transfers is done OR if you want to choose another option."
sleep 2
read key