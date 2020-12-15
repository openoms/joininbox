#!/bin/bash

source /home/joinmarket/_functions.sh

clear

generateJMconfig

echo "See how to prepare a remote node to accept the JoinMarket connection:"
echo "https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md#prepare-a-remote-node-to-accept-the-joinmarket-connection"  
echo
echo "Input the RPC username of the remote bitcoin node:"
read rpc_user
echo "Input the RPC password of the remote node:"
read rpc_pass
echo "Type or paste the LAN IP or .onion address of the remote node:"
read rpc_host
echo "Input the RPC port (8332 by default):"
read rpc_port 

echo "# Checking the remote RPC connection with curl..."
echo

function checkRPC {
tor=""
if [ $(echo $rpc_addr | grep -c .onion) -gt 0 ]; then
  tor="torify"
  echo "# Connecting over Tor..."
  echo
fi
$tor curl --data-binary \
'{"jsonrpc": "1.0", "id":"# Connected to bitcoinRPC successfully", "method": "getblockcount", "params": [] }' \
http://$rpc_user:$rpc_pass@$rpc_addr:$rpc_port
} 

if [ $(checkRPC 2>/dev/null | grep -c "bitcoinRPC") -gt 0 ]; then
  echo "# Connected to bitcoinRPC successfully"
  echo
  echo "# Blockheight on the connected node: $(checkRPC 2>/dev/null|grep "result"|cut -d":" -f2|cut -d"," -f1)"
  echo
  python /home/joinmarket/set.bitcoinrpc.py --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host --rpc_port=$rpc_port
else
  echo "# Could not connect to bitcoinRPC with the error:"
  echo 
  checkRPC
  echo
  echo "See how to prepare a remote node to accept the JoinMarket connection:"
  echo "https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md#prepare-a-remote-node-to-accept-the-joinmarket-connection" 
fi
