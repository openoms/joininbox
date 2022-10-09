#!/bin/bash

# ssh -L local_port:destination_server_ip:remote_port ssh_server_hostname
# ports: 28283 28183 62601

if  [ $#1 -eq 0 ];then
  echo
  echo "# Input the IP address of your JoininBox instance:"
  read joininboxip
else
  joininboxip=$1
fi
command="ssh -L 62601:${joininboxip}:62601 -L 28283:${joininboxip}:28283 -L 28183:${joininboxip}:28183 joinmarket@${joininboxip}"

echo "Running:"
echo "$command"

# run command
$command
