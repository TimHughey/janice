#!/bin/zsh

mcr_esp="dev_esp32"
where_host="jophiel"
dev="/dev/ttyUSB0"

host=$(hostname)

[[ $host -ne $where_host ]] && echo "not on host" && exit 255
[[ ! -c $dev ]] && echo "$dev does not exist" && exit 254

echo "monitoring $mcr_esp from $dev"
while true; do
	grabserial -d $dev 
	sleep 1
done
