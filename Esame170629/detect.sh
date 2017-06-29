#!/bin/bash
echo > "/etc/serversprec"
while sleep 5 ; do
	echo > "/root/up.server.list"
	echo > "/etc/newserversprec"
	for S in `seq 10 253` do 
		SERVER = 10.1.1."$S"
        	if ping -c 1 -W 1 "$SERVER" > /dev/null 2>&1 ; then
			if cat "/etc/serversprec" | grep -q "$SERVER" ; then	
			else
				init.sh "$SERVER"
			fi
			echo "$SERVER" >> "/root/up.server.list"
			echo "$SERVER" >> "/etc/newserversprec"
		else		
                
        	fi
	done
	rm -f "/etc/serversprec"
	mv "/etc/newserversprec" "/etc/serversprec"
done

