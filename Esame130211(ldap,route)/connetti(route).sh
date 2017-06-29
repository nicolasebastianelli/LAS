#!/bin/bash

while true
do
	case "$1" in 
	FAST)
		
		ping -c 1 -w 1 192.168.56.202
		;;

	CHEAP)
		ping -c 1 -w 1 192.168.56.203
		;;

	*)
		echo Usage: $0 '[FAST|CHEAP]'
		exit 1
		;;
	esac
   # stampo il gateway dell'interfaccia
   echo -n "default gateway is: "
   route -n | while read net gw mask other ; do
	if [ "$net" = "0.0.0.0" -a "$mask" = "0.0.0.0" ] ; then
		echo $gw
	fi
   done
   sleep 60
done
