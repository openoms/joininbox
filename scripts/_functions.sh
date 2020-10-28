#!/bin/bash

walletPath="/home/joinmarket/.joinmarket/wallets/"
currentJBcommit=$(cd $HOME/joininbox; git describe --tags)
currentJBtag=$(cd ~/joininbox; git tag | sort -V | tail -1)
currentJMversion=$(cd $HOME/joinmarket-clientserver; git describe --tags)

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

# errorOnInstall
errorOnInstall() {
if [ "$1" -gt 0 ]; then
  DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
    --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
fi
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
# puts the Yield Generator uptime to $JMUptime
source /home/joinmarket/joinin.conf
JMpid=$(pgrep -f "python yg-privacyenhanced.py $YGwallet --wallet-password-stdin" 2>/dev/null | head -1)
JMUptimeInSeconds=$(ps -p $JMpid -oetime= 2>/dev/null | tr '-' ':' | awk -F: '{ total=0; m=1; } { for (i=0; i < NF; i++) {total += $(NF-i)*m; m *= i >= 2 ? 24 : 60 }} {print total}')
JMUptime=$(printf '%dd:%dh:%dm\n' $((JMUptimeInSeconds/86400)) $((JMUptimeInSeconds%86400/3600)) $((JMUptimeInSeconds%3600/60)))
}

function installJoinMarket() {
  source /home/joinmarket/joinin.conf
  JMVersion="v0.7.2"
  cd /home/joinmarket
  # PySide2 for armf: https://packages.debian.org/buster/python3-pyside2.qtcore
  echo "# installing ARM specific dependencies to run the QT GUI"
  sudo apt install -y python3-pyside2.qtcore python3-pyside2.qtgui \
  python3-pyside2.qtwidgets zlib1g-dev libjpeg-dev python3-pyqt5 libltdl-dev
  # https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/668#issuecomment-717815719
  sudo -u joinmarket pip install coincurve
  echo "# installing JoinMarket"
  sudo -u joinmarket git clone https://github.com/Joinmarket-Org/joinmarket-clientserver
  cd joinmarket-clientserver
  sudo -u joinmarket git reset --hard $JMVersion
  # do not stop at installing debian dependencies
  sudo -u joinmarket sed -i \
  "s#^        if ! sudo apt-get install \${deb_deps\[@\]}; then#\
        if ! sudo apt-get install -y \${deb_deps\[@\]}; then#g" install.sh
  if [ ${cpu} != "x86_64" ]; then
    echo "# Make install.sh set up jmvenv with -- system-site-packages on arm"
    # and import the PySide2 armf package from the system
    sudo -u joinmarket sed -i "s#^    virtualenv -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1#\
      virtualenv --system-site-packages -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1 ;\
    /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c \'import PySide2\'\
    #g" install.sh
    # don't install PySide2 - using the system-site-package instead 
    sudo -u joinmarket sed -i "s#^PySide2##g" requirements/gui.txt
    # don't install PyQt5 - using the system package instead 
    sudo -u joinmarket sed -i "s#^PyQt5==5.14.2##g" requirements/gui.txt
  fi
  sudo -u joinmarket ./install.sh --with-qt
  echo "# installed JoinMarket $JMVersion"
}

function updateJoininBox() {
if [ "$1" = "reset" ];then
  echo "# Removing the joininbox source code"
  sudo rm -rf /home/joinmarket/joininbox
  echo "# Downloading the latest joininbox source code"
fi
# clone repo in case it is not present
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git /home/joinmarket/joininbox 2>/dev/null
echo "# Checking the updates in https://github.com/openoms/joininbox"
# based on https://github.com/apotdevin/thunderhub/blob/master/scripts/updateToLatest.sh
cd /home/joinmarket/joininbox
# fetch latest master
sudo -u joinmarket git fetch
if [ "$1" = "commit" ]; then
  TAG=$(git describe --tags)
  echo "# Updating to the latest commit in the default branch"
else
  TAG=$(git tag | sort -V | tail -1)
  # unset $1
  set --
  UPSTREAM=${1:-'@{u}'}
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse "$UPSTREAM")
  if [ $LOCAL = $REMOTE ]; then
    echo "# You are up-to-date on version" $TAG
    exit 0
  fi
fi
echo "# Pulling latest changes..."
sudo -u joinmarket git pull -p
sudo -u joinmarket git reset --hard $TAG
echo "# Updated to version" $TAG
echo "# Copying the scripts in place"
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/*.* /home/joinmarket/
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
}