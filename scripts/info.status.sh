#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

color_red='\033[0;31m'
color_green='\033[0;32m'
color_amber='\033[0;33m'
color_yellow='\033[1;93m'
color_gray='\033[0;37m'
color_purple='\033[0;35m'

# blockheight
configFile=/home/joinmarket/.joinmarket/joinmarket.cfg

rpc_user=$(cat $configFile | grep rpc_user | awk '{print $3}')
rpc_password=$(cat $configFile | grep rpc_password | awk '{print $3}')
rpc_host=$(cat $configFile | grep rpc_host | awk '{print $3}')
rpc_port=$(cat $configFile | grep rpc_port | awk '{print $3}')

blockheight=$(torify curl --data-binary \
'{"jsonrpc": "1.0", "id":"curltest", "method": "getblockcount", "params": [] }' \
http://"$rpc_user":"$rpc_password"@"$rpc_host":"$rpc_port" 2>/dev/null | jq -r '.result')

# get uptime & load
load=$(w | head -n 1 | cut -d 'v' -f2 | cut -d ':' -f2)

# get CPU temp - no measurement in a VM
cpu=0
if [ -d "/sys/class/thermal/thermal_zone0/" ]; then
  cpu=$(cat /sys/class/thermal/thermal_zone0/temp)
fi
tempC=$((cpu/1000))
tempF=$(((tempC * 18 + 325) / 10))

# get memory
ram_avail=$(free -m | grep Mem | awk '{ print $7 }')
ram=$(printf "%sM / %sM" "${ram_avail}" "$(free -m | grep Mem | awk '{ print $2 }')")

if [ ${ram_avail} -lt 50 ]; then
  color_ram="${color_red}\e[7m"
else
  color_ram=${color_green}
fi

# get name of active interface (eth0 or wlan0)
network_active_if=$(ip route get 255.255.255.255 | awk -- '{print $4}' | head -n 1)

# get network traffic
# ifconfig does not show eth0 on Armbian or in a VM - get first traffic info
isArmbian=$(cat /etc/os-release 2>/dev/null | grep -c 'Debian')
if [ ${isArmbian} -gt 0 ] || [ ! -d "/sys/class/thermal/thermal_zone0/" ]; then
  network_rx=$(ifconfig | grep -m1 'RX packets' | awk '{ print $6$7 }' | sed 's/[()]//g')
  network_tx=$(ifconfig | grep -m1 'TX packets' | awk '{ print $6$7 }' | sed 's/[()]//g')
else
  network_rx=$(ifconfig ${network_active_if} | grep 'RX packets' | awk '{ print $6$7 }' | sed 's/[()]//g')
  network_tx=$(ifconfig ${network_active_if} | grep 'TX packets' | awk '{ print $6$7 }' | sed 's/[()]//g')
fi

sleep 5
clear
printf "
${color_yellow}
${color_yellow}
${color_yellow}
${color_yellow} ${color_amber}%s ${color_green} ${ln_alias} ${upsInfo}
${color_yellow} ${color_gray}${network^} JoininBox 
${color_yellow} ${color_yellow}%s
${color_yellow} ${color_gray}%s, temp %s°C %s°F
${color_yellow} ${color_gray}Free Mem ${color_ram}${ram} ${color_gray} ${color_gray}
${color_yellow} ${color_gray}ssh joinmarket@${color_green}${local_ip}${color_gray} d${network_rx} u${network_tx}
${color_yellow} ${color_gray}${webinterfaceInfo}
${color_yellow} ${color_gray}${network} ${color_green}${networkVersion} ${chain}net ${color_gray}
${color_yellow} ${color_gray}${public_addr_pre}${public_color}${public_addr} ${public}${networkConnectionsInfo}
${color_yellow} ${color_gray}
${color_yellow} ${color_gray}${ln_feeReport}
${color_yellow}
${color_yellow}${ln_publicColor}${ln_external}${color_gray}

" \
"RaspiBlitz v${codeVersion}" \
"-------------------------------------------" \
"CPU load${load##up*,  }" "${tempC}" "${tempF}" \
"${hdd}" "${sync_percentage}"
