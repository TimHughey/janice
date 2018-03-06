#!/bin/zsh

mcr_esp="bisto"
where_host="loki"
dev="/dev/ttyUSB0"

host=$(hostname)

[[ $host -ne $where_host ]] && echo "not on host" && exit 255
[[ -c $dev ]] && echo "$dev does not exist" && exit 254

echo "monitoring $mcp_esp"
while true; do
	grabserial -d $dev 
	sleep 1
done
