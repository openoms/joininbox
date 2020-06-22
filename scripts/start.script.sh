#!/bin/bash

source /home/joinmarket/menu.functions.sh

script="$1"
if [ ${#script} -eq 0 ]; then
  echo "must specify a script to run"
  exit 1
fi

wallet="$2"
if [ ${#wallet} -eq 0 ] || [ ${wallet} == "" ]; then
  echo "must specify a wallet to use"
  exit 1
fi

option="$3"
if [ ${#option} -eq 0 ] || [ ${option} = "nooption" ]; then
  option=""
fi

mixdepth="$4"
if [ ${#mixdepth} -eq 0 ]; then
  mixdepth=""
else
  mixdepth="-m$4"
fi

makercount="$5"
if [ ${#makercount} -eq 0 ] || [ ${makercount} = "nomakercount" ]; then
  makercount=""
else
  makercount="-N$5"
fi

amount="$6"
if [ ${#amount} -eq 0 ]; then
  amount=""
fi

address="$7"
if [ ${#address} -eq 0 ]; then
  address=""
fi

nickname="$8"
if [ ${#nickname} -eq 0 ]; then
  nickname=""
else
  nickname="-T $8"
fi

source /home/joinmarket/joinin.conf
if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

clear
# display 
echo "Running the command:
$tor python $script.py \
$makercount $mixdepth $wallet $option $amount $address $nickname
"
# run
. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
$tor python ~/joinmarket-clientserver/scripts/$script.py \
$makercount $mixdepth $wallet $option $amount $address $nickname