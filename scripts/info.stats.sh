#!/bin/bash

source /home/joinmarket/_functions.sh

feereport
YGuptime

echo "JoinMarket stats:day:week:month:all
coinjoins as a Maker:$dayCoinjoins:$weekCoinjoins:$monthCoinjoins:$allCoinjoins
sats earned:$dayEarned:$weekEarned:$monthEarned:$allEarned
Maker uptime:$JMUptime" | column -t -s:
