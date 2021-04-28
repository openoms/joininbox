#!/bin/bash

source /home/joinmarket/_functions.sh

feereport
YGuptime
sixteencharname=$(YGnickname)

echo "\
JoinMarket stats:day:week:month
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned
$sixteencharname up:$JMUptime" | column -t -s:
