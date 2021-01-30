#!/bin/bash

source /home/joinmarket/_functions.sh

feereport
YGuptime

echo "JoinMarket stats:day:week:month
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned
Maker uptime:$JMUptime" | column -t -s:
