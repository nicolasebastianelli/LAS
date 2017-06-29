#!/bin/bash

LASTENTRY = "0"
LASTTIME = $( date +%s )
GUASTO = "no"
PIDDETECH = "-1"
while true do
	ACTUALENTRY = $( cat "/var/log/packets.log" | tail -1)
	if [ "$LASTENTRY" -ne "$ACTUALENTRY" ] then
		if [ "$GUASTO" -eq "si" ] then
			GUASTO="no"
			kill "$PIDDETECH"
			crontab -r "*/15 * * * * /pathto/monitor.sh"
		fi
		LASTENTRY = "$ACTUALENTRY"
		LASTTIME = $( date +%s )
		echo "$ACTUALENTRY" | ldapadd -x -D  "cn=traffic,dc=labammsis" -w  admin 
	else
		MIN = $(( $( date +%s ) - "$LASTTIME" ))
		MIN = $(( "$MIN" / 60))
		if [ "$MIN" -gt 20 ] then
			GUASTO = "si"
			detect.sh & 
			PIDDETECH = "$!"
			crontab -e "*/15 * * * * /pathto/monitor.sh"
		fi
	fi
done
