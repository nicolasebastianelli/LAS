#!/bin/bash

echo "$1" | sed -e 's/\./ /' | ( read a b c d
if "$a" -le 0 -o "$a" -gt 255 -o "$b" -lt 0 -o "$b" -gt 255 -o "$c" -lt 0 -o "$c" -gt 255 -o "$d" -le 0 -o "$d" -ge 255 ; then
	echo "primo parametro errato" >&2
	exit 1
fi

if [ "$2" = "open"] ; then

	iptables -N "FW_$1"
	iptables -N "ACCEPT_AND_COUNT_$1" 

	iptables -A "ACCEPT_AND_COUNT_$1" -j ACCEPT

	iptables -A FORWARD -s "$1" -j "FW_$1"
	iptables -A FORWARD -m state --state ESTABLISHED -d "$1" -j "ACCEPT_AND_COUNT_$1"
	iptables -t nat -A POSTROUTING -s "$1" ! -d 10.1.1.0/24 -j MASQUERADE 	

	cat /etc/allowed_ports | while read PROTO PORT ; do
		iptables -A "FW_$1" -s "$1"-p $PROTO --dport $PORT -j "ACCEPT_AND_COUNT_$1"
	done

elif [ "$2" = "close" ] ; then 

	iptables -F "FW_$1"
	iptables -F "ACCEPT_AND_COUNT_$1"

	iptables -D FORWARD -s "$1" -j "FW_$1"
	iptables -D FORWARD -m state --state ESTABLISHED -d "$1" -j "ACCEPT_AND_COUNT_$1"
	iptables -t nat -D POSTROUTING -s "$1" ! -d 10.1.1.0/24 -j MASQUERADE 	

	iptables -X "FW_$1"
	iptables -X "ACCEPT_AND_COUNT_$1"

else
  	echo "secondo parametro errato" >&2
  	exit 2
fi


done

