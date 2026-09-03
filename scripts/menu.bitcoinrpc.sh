#!/bin/bash

source /home/joinmarket/_functions.sh

# check connectedRemoteNode var in joinin.conf
if ! grep -Eq "^connectedRemoteNode=" $joininConfPath; then
  echo "connectedRemoteNode=off" >> $joininConfPath
fi
if ! grep -Eq "^RPCoverTor=" $joininConfPath; then
  echo "RPCoverTor=off" >> $joininConfPath
fi
if ! grep -Eq "^network=" $joininConfPath; then
  echo "network=unknown" >> $joininConfPath
fi
clear

function displayHelp {
  echo "# See how to prepare a remote node to accept the JoinMarket connection:"
  echo "# https://github.com/openoms/joininbox/blob/master/prepare_remote_node.md"
}

function inputRPC {
  echo
  echo "Input the RPC username of the remote bitcoin node:"
  read -r rpc_user
  echo "Input the RPC password of the remote node:"
  read -r -s rpc_pass
  echo
  echo "Type or paste the LAN IP or .onion address of the remote node:"
  read -r rpc_host
  echo "Input the RPC port (8332 by default):"
  read -r rpc_port
}

function curlConfigQuote {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\r'/\\r}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

function checkRPC {
  local status

  rpcAuthConfig=$(mktemp -p /dev/shm/)
  chmod 600 "$rpcAuthConfig"
  printf 'user = "%s"\n' "$(curlConfigQuote "$rpc_user:$rpc_pass")" > "$rpcAuthConfig"
  if [[ "${rpc_host,,}" = *.onion ]]; then
    echo "# Connecting over Tor..."
    echo
    torsocks curl -sS --config "$rpcAuthConfig" --data-binary \
      '{"jsonrpc": "1.0", "id":"# Connected to bitcoinRPC successfully", "method": "getblockcount", "params": [] }' \
      "http://${rpc_host}:${rpc_port}/"
    status=$?
  else
    curl -sS --config "$rpcAuthConfig" --data-binary \
      '{"jsonrpc": "1.0", "id":"# Connected to bitcoinRPC successfully", "method": "getblockcount", "params": [] }' \
      "http://${rpc_host}:${rpc_port}/"
    status=$?
  fi
  rm -f "$rpcAuthConfig"
  rpcAuthConfig=""
  return "$status"
}

displayHelp
inputRPC
echo "# Checking the remote RPC connection with curl..."
echo
rpcAuthConfig=""
trap 'rm -f "$connectionOutput" "${rpcAuthConfig:-}"' EXIT
connectionOutput=$(mktemp -p /dev/shm/)
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
printf '%s' "$rpc_pass" | \
  sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh configure-remote \
    mainnet "$rpc_user" "$rpc_host" "$rpc_port"
unset rpc_pass
sed -i "s#^connectedRemoteNode=.*#connectedRemoteNode=on#g" $joininConfPath
if [[ "${rpc_host,,}" = *.onion ]]; then
  sed -i "s#^RPCoverTor=.*#RPCoverTor=on#g" $joininConfPath
else
  sed -i "s#^RPCoverTor=.*#RPCoverTor=off#g" $joininConfPath
fi
sed -i "s#^network=.*#network=mainnet#g" $joininConfPath
echo
