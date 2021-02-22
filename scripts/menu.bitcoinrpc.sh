#!/bin/bash

source /home/joinmarket/_functions.sh

# check connectedRemoteNode var in joinin.conf
if ! grep -Eq "^connectedRemoteNode=" /home/joinmarket/joinin.conf; then
  echo "connectedRemoteNode=off" >> /home/joinmarket/joinin.conf
fi
clear

generateJMconfig

function displayHelp {
  echo "# See how to prepare a remote node to accept the JoinMarket connection:"
  echo "# https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md"  
}

function inputRPC {
  echo
  echo "Input the RPC username of the remote bitcoin node:"
  read rpc_user
  echo "Input the RPC password of the remote node:"
  read rpc_pass
  echo "Type or paste the LAN IP or .onion address of the remote node:"
  read rpc_host
  echo "Input the RPC port (8332 by default):"
  read rpc_port
}

function checkRPC {
  tor=""
  if [ $(echo $rpc_host | grep -c .onion) -gt 0 ]; then
    tor="torify"
    echo "# Connecting over Tor..."
    echo
  fi
  $tor curl -sS --data-binary \
  '{"jsonrpc": "1.0", "id":"# Connected to bitcoinRPC successfully", "method": "getblockcount", "params": [] }' \
  http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port
} 

displayHelp
inputRPC
echo "# Checking the remote RPC connection with curl..."
echo
connectionOutput=$(mktemp 2>/dev/null)
connectionSuccess=$(checkRPC 2>$connectionOutput | grep -c "bitcoinRPC")
while [ $connectionSuccess -eq 0 ]; do
  echo
  echo "# Could not connect to bitcoinRPC with the error:"
  cat $connectionOutput
  echo
  displayHelp
  echo
  echo "Press ENTER to retry or CTLR+C to abort"
  read key
  echo "---------------------------------------"
  inputRPC
  connectionSuccess=$(checkRPC 2>$connectionOutput | grep -c "bitcoinRPC")
done

echo
echo "# Connected to bitcoinRPC successfully"
echo
echo "# Blockheight on the connected node: $(checkRPC 2>/dev/null|grep "result"|cut -d":" -f2|cut -d"," -f1)"
echo
rpc_wallet=joininbox
walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
while [ $walletFound -eq 0 ]; do
  echo "# Setting a watch only wallet for the remote Bitcoin Core named $rpc_wallet"
  customRPC "# Create the bitcoind wallet" "createwallet" "$rpc_wallet"
  echo
  walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
  while [ $walletFound -eq 0 ]; do
    echo "# Making sure the set $rpc_wallet wallet is loaded in bitcoind"
    echo
    customRPC "# Load wallet in bitcoind" "loadwallet" "$rpc_wallet"
    walletFound=$(customRPC "# Check wallet" "listwallets" 2>$connectionOutput | grep -c "$rpc_wallet")
  done
done
python /home/joinmarket/set.bitcoinrpc.py --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host --rpc_port=$rpc_port --rpc_wallet=$rpc_wallet
echo
echo "# The bitcoinRPC connection settings are set in the joinmarket.cfg"
sed -i "s#^connectedRemoteNode=.*#connectedRemoteNode=on#g" /home/joinmarket/joinin.conf
echo 
