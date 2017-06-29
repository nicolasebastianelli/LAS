#!/bin/bash

io=`whoami`

ldapsearch -h 10.1.1.254 -x -s sub -b "dc=labammsis" (&("objectClass=utente")("user=$io") > /tmp/ricerca.ldif
num=`cat /tmp/ricerca.ldif | grep "^dn: " | wc -l`

if [ "$num" -eq 1 ]
then
	Stato=`cat /tmp/ricerca.ldif | grep "^Stato: " | awk '{ print $2 }'`
	TempoResiduoMinuti=`cat /tmp/ricerca.ldif | grep "^TempoResiduoMinuti: " | awk '{ print $2 }'`
	TrafficoResiduoKB=`cat /tmp/ricerca.ldif | grep "^TrafficoResiduoKB: " | awk '{ print $2 }'`
	rm -f /tmp/ricerca.ldif

	if [ "$Stato" = "Disconnesso" ] && [ "$TempoResiduoMinuti" -gt 0 ] && [ "$TrafficoResiduoKB" -gt 0 ]
	then
		myIp= `ifconfig eth1 | grep "inet addr" | awk '{print $2}' | cut -d: -f2`
		echo "dn: user=$io,dc=lab4,dc=ingbo" > /tmp/modifica.ldif
		echo "Stato: Connesso" >> /tmp/modifica.ldif	
		echo "Ip: $myIp" >> /tmp/modifica.ldif	
		
		ldapmodify -h 10.1.1.254 -x -D  "cn=admin,dc=labammsis" -w  admin -f /tmp/modifica.ldif
		rm /tmp/modifica.ldif	

     		lastbackup=`ssh 10.1.1.254 "ls -t /users/'$io' | head -1"` 
     		ssh 10.1.1.254 "cat /users/'$io'/'$lastbackup'" | tar -C $HOME -x -z -f - 
		exit 0
	else
		logout.sh
		exit 1	
	fi 	 		
else
	exit 2
fi 


