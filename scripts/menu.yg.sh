#!/bin/bash
# YG menu options

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

checkRPCwallet

# add default value to joinin config if needed
if ! grep -Eq "^YGwallet=" $joininConfPath; then
  echo "YGwallet=nil" >> $joininConfPath
fi

# BASIC MENU INFO
HEIGHT=14
WIDTH=52
CHOICE_HEIGHT=21
TITLE="Yield Generator options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(
  MAKER "Run the Yield Generator"
  JMCONF "YG settings in the joinmarket.cfg"
  YGLIST "List the past YG activity"
  NICKNAME "Show the last used counterparty name"
  SERVICE "Monitor the YG service (INFO)"
  LOGS "View the last YG logfile (DEBUG)"
  STOP "Stop the YG service"
  TIMELOCK "Create a Fidelity Bond address"
)

CHOICE=$(dialog \
          --clear \
          --backtitle "$BACKTITLE" \
          --title "$TITLE" \
          --ok-label "Select" \
          --cancel-label "Back" \
          --menu "$MENU" \
            $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "${OPTIONS[@]}" \
            2>&1 >/dev/tty)

case $CHOICE in

  MAKER)
    menu_MAKER;;
  JMCONF)
    /home/joinmarket/install.joinmarket.sh config
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.yg.sh;;
  YGLIST)
    dialog \
    --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
    --prgbox "column /home/joinmarket/.joinmarket/logs/yigen-statement.csv -t -s ","" 100 140
    echo "# returning to the menu..."
    sleep 1
    /home/joinmarket/menu.yg.sh;;
  NICKNAME)
    name=$(YGnickname)
    whiptail \
      --title "Counterparty name"  \
      --msgbox "The last used counterparty name for the Order Book:\n
$name\n
Check if active in: https://nixbitcoin.org/obwatcher/
or use the local Order Book" 12 55
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.yg.sh;;
  SERVICE)
      dialog \
        --title "Monitoring the Yield Generator"  \
        --msgbox "
Shows the service status with INFO logs using:

sudo systemctl status yg-privacyenhanced

Press CTRL+C to exit to the command line.
Use: 'menu' for the JoininBox options." 11 50
    sudo systemctl status yg-privacyenhanced;;
  LOGS)
    dialog \
    --title "Monitoring the Yield Generator"  \
    --msgbox "
Will tail the latest YG logfile from:

/home/joinmarket/.joinmarket/logs/

Press CTRL+C to exit and return to the menu." 10 50
    cd /home/joinmarket/.joinmarket/logs || exit 1 
    ls -t | grep J5 | head -n 1 | xargs tail -fn1000
    echo
    echo "Press ENTER to return to menu"
    read key
    cd /home/joinmarket/joinmarket-clientserver/scripts/ || exit 1
    /home/joinmarket/menu.yg.sh;;            
  STOP)
    stopYG
    echo
    echo "Press ENTER to return to the menu..."
    read key;;
  TIMELOCK)
    # wallet
    chooseWallet noLockFileCheck
    # (gettimelockaddress) Obtain a timelocked address. Argument is locktime value as yyyy-mm. For example `2021-03`.
    # locktime
    trap 'rm -f "$locktime"' EXIT
    locktime=$(mktemp -p /dev/shm/)
    dialog --backtitle "Obtain a timelocked address" \
    --title "Obtain a timelocked address" \
    --inputbox "
Enter a date until which the coin sent to the address should be locked.
The format is: yyyy-mm. For example: 
2021-03
" 12 60 2> "$locktime"
    openMenuIfCancelled $?
    echo
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    command="$tor python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py $(cat $wallet) gettimelockaddress $(cat $locktime)"
    echo "Running the command:"
    echo "$command"
    $command
    echo
    echo "Note that only the most valuable Fidelity Bond will be taken into account."
    echo "Send only one private coin to be locked until the chosen date."
    echo
    echo "Press ENTER to return to the menu"
    read key;;
esac
