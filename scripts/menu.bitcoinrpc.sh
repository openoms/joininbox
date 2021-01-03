#!/bin/bash

source /home/joinmarket/_functions.sh

clear

generateJMconfig

echo "See how to prepare a remote node to accept the JoinMarket connection:"
echo "https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md#prepare-a-remote-node-to-accept-the-joinmarket-connection"  

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
$tor curl --data-binary \
'{"jsonrpc": "1.0", "id":"# Connected to bitcoinRPC successfully", "method": "getblockcount", "params": [] }' \
http://$rpc_user:$rpc_pass@$rpc_host:$rpc_port
} 

inputRPC
echo "# Checking the remote RPC connection with curl..."
echo
checkRPC

connectionSuccess=$(checkRPC 2>/dev/null | grep -c "bitcoinRPC")
while [ $connectionSuccess -eq 0 ]; do
  echo
  echo "# Could not connect to bitcoinRPC with the error:"
  checkRPC
  echo
  echo "See how to prepare a remote node to accept the JoinMarket connection:"
  echo "https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md#prepare-a-remote-node-to-accept-the-joinmarket-connection" 
  echo
  echo "Press ENTER to retry or CTLR+C to abort"
  read key
  inputRPC
  connectionSuccess=$(checkRPC 2>/dev/null | grep -c "bitcoinRPC")
done

echo
echo "# Connected to bitcoinRPC successfully"
echo
echo "# Blockheight on the connected node: $(checkRPC 2>/dev/null|grep "result"|cut -d":" -f2|cut -d"," -f1)"
echo
python /home/joinmarket/set.bitcoinrpc.py --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host --rpc_port=$rpc_port
echo
echo "# The bitcoinRPC connection settings are set in the joinmarket.cfg"
echo 
echo "Press ENTER to continue"
read key