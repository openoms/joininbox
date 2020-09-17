#!/bin/bash

# shows the fees earned as a Maker

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

echo "
coinjoins as a Maker
day:   $dayCoinjoins
week:  $weekCoinjoins
month: $monthCoinjoins
all:   $allCoinjoins

sats earned
day:   $dayEarned
week:  $weekEarned
month: $monthEarned
all:   $allEarned
"