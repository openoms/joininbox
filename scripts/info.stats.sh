#!/bin/bash

source /home/joinmarket/_functions.sh

sixteencharname=$(YGnickname)

# feereport
# puts the fees earned as a Maker into variables
INPUT=/home/joinmarket/.joinmarket/logs/yigen-statement.csv
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
  if [ "$my_input_count" -gt 0 ]; then
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

# YGuptime
# puts the Yield Generator uptime to $JMUptime
JMpid=$(pgrep -f "python yg-privacyenhanced.py $YGwallet --wallet-password-stdin" 2>/dev/null | head -1)
JMUptimeInSeconds=$(ps -p $JMpid -oetime= 2>/dev/null | tr '-' ':' | awk -F: '{ total=0; m=1; } { for (i=0; i < NF; i++) {total += $(NF-i)*m; m *= i >= 2 ? 24 : 60 }} {print total}')
JMUptime=$(printf '%dd:%dh:%dm\n' $((JMUptimeInSeconds/86400)) $((JMUptimeInSeconds%86400/3600)) $((JMUptimeInSeconds%3600/60)))
if [ "$JMUptime" = "0:0:0" ]; then
  JMUptime="not running"
fi
trap 'rm -f "$JMstats"' EXIT
JMstats=$(mktemp -p /dev/shm)

if [ "$1" != "showAllEarned" ]; then 
  # keep original behaviour for the raspiblitz display (00infoBlitz.sh)
  echo "\
JoinMarket stats:day:week:month
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned
$sixteencharname up:$JMUptime" | column -t -s: > $JMstats

else
  echo "\
JoinMarket stats:day:week:month:all
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins:$allCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned:$allEarned
$sixteencharname up:$JMUptime" | column -t -s: > $JMstats
fi

cat "$JMstats"

