#!/bin/bash

walletPath="/home/joinmarket/.joinmarket/wallets/"

# openMenuIfCancelled
openMenuIfCancelled() {
pressed=$1
case $pressed in
  1)
    echo "Cancelled"
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
  255)
    echo "ESC pressed."
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
esac
}

# write password into a file (to be shredded)
passwordToFile() {
# get password
data=$(mktemp 2>/dev/null)
# trap it
trap 'rm -f $data' 0 1 2 5 15
dialog --backtitle "Enter password" \
       --title "Enter password" \
       --insecure \
       --passwordbox "Type or paste the wallet decryption password" 8 52 2> "$data"
# make decison
pressed=$?
case $pressed in
  0)
    touch /home/joinmarket/.pw
    chmod 600 /home/joinmarket/.pw
    tee /home/joinmarket/.pw 1>/dev/null < "$data"
    shred "$data"
    ;;
  1)
    shred "$data"
    shred "$wallet"
    rm -f .pw
    echo "Cancelled"
    exit 1
    ;;
  255)
    shred "$data"
    shred "$wallet"
    rm -f .pw
    [ -s "$data" ] &&  cat "$data" || echo "ESC pressed."
    exit 1
    ;;
esac
}

# chooseWallet
chooseWallet() {
source /home/joinmarket/joinin.conf
wallet=$(mktemp 2>/dev/null)
if [ "$defaultWallet" = "off" ]; then
  wallet=$(mktemp 2>/dev/null)
  dialog --backtitle "Choose a wallet by typing the full name of the file" \
  --title "Choose a wallet by typing the full name of the file" \
  --fselect "$walletPath" 10 60 2> "$wallet"
  openMenuIfCancelled $?
else
  echo "$defaultWallet" > "$wallet"
fi
}

function stopYG() {
# stop the background process (equivalent to CTRL+C)
# use wallet from joinin.conf
source /home/joinmarket/joinin.conf
pkill -sigint -f "python yg-privacyenhanced.py $YGwallet --wallet-password-stdin"
# pgrep python | xargs kill -sigint             
# remove the service
sudo systemctl stop yg-privacyenhanced
sudo systemctl disable yg-privacyenhanced
# check for failed services
# sudo systemctl list-units --type=service
sudo systemctl reset-failed
# make sure the lock file is deleted 
rm -f ~/.joinmarket/wallets/.$wallet.lock
# for old version <v0.6.3
rm -f ~/.joinmarket/wallets/$wallet.lock 2>/dev/null
echo "# stopped the Yield Generator background service"
}

function QRinTerminal() {
  datastring=$1
  if [ ${#datastring} -eq 0 ]; then
    echo "error='missing string'"
  fi
  qrencode -t ANSI256 "${datastring}"
  echo "(To shrink QR code: MacOS press CMD- / Linux press CTRL-)"
}

function feereport() {
# puts the fees earned as a Maker into variables
INPUT=$HOME/.joinmarket/logs/yigen-statement.csv
allEarned=0
allCoinjoins=0
monthEarned=0
monthCoinjoins=0
weekEarned=0
weekCoinjoins=0
dayEarned=0
dayCoinjoins=0
unixtimeMonthAgo=$(date -d "1 month ago" +%s)
unixtimeWeekAgo=$(date -d "1 week ago" +%s)
unixtimeDayAgo=$(date -d "1 day ago" +%s)
OLDIFS=$IFS
IFS=","
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
#timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes
while read -r timestamp cj_amount_satoshi my_input_count my_input_value_satoshi  cjfee_satoshi  earned_satoshi  confirm_time_min  notes
do
  unixtimeEvent=$(date -d "$timestamp" +%s 2>/dev/null)
  if [ "$earned_satoshi" -gt 0 ]; then
    allEarned=$(( allEarned + earned_satoshi ))
    allCoinjoins=$(( allCoinjoins + 1 ))
    if [ "$unixtimeEvent" -gt "$unixtimeMonthAgo" ]; then
      monthEarned=$(( monthEarned + earned_satoshi ))
      monthCoinjoins=$(( monthCoinjoins + 1 ))
      if [ "$unixtimeEvent" -gt "$unixtimeWeekAgo" ]; then
        weekEarned=$(( weekEarned + earned_satoshi ))
        weekCoinjoins=$((weekCoinjoins+1))
        if [ "$unixtimeEvent" -gt "$unixtimeDayAgo" ]; then
          dayEarned=$((dayEarned+earned_satoshi))
          dayCoinjoins=$((dayCoinjoins+1))
        fi
      fi
    fi
  fi 2>/dev/null
done < "$INPUT"
IFS=$OLDIFS
}

function YGuptime() {
# puts the Yild Generator uptime to $JMUptime
source /home/joinmarket/joinin.conf
JMpid=$(pgrep -f "python yg-privacyenhanced.py $YGwallet --wallet-password-stdin" | head -1)
JMUptimeInSeconds=$(ps -p $JMpid -oetime= | tr '-' ':' | awk -F: '{ total=0; m=1; } { for (i=0; i < NF; i++) {total += $(NF-i)*m; m *= i >= 2 ? 24 : 60 }} {print total}')
JMUptime=$(printf '%dd:%dh:%dm\n' $((JMUptimeInSeconds/86400)) $((JMUptimeInSeconds%86400/3600)) $((JMUptimeInSeconds%3600/60)))
}