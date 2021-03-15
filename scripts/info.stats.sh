#!/bin/bash

source /home/joinmarket/_functions.sh

feereport
YGuptime

name=$(YGnickname)

echo "JoinMarket stats:day:week:month
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned
Maker ($name) uptime:$JMUptime" | column -t -s: