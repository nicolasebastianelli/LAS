#!/bin/bash

# per permettere l'esecuzione dello script ogni minuto è necessario impostare cron nel seguente modo
# 1) editare la tabella di cron con il comando: crontab -e
# 2) inserire la riga: * * * * * /path/to/decrementa.sh
# /path/to/ il percorso in cui si trova lo script 

ldapsearch -x -s sub -b "dc=labammsis" (&("objectClass=utente")("Stato=Connesso")) | grep "^user: " | awk '{ print $2 }' | while read U ; do
	VALORI=`ldapsearch -x -s base -b "user=$U,dc=lab4,dc=ingbo" | egrep '^(Ip|TempoResiduoMinuti|TrafficoResiduoKB): ' | sort`
	IP=`echo $VALORI | awk '{ print $2 }'`
	TRMIN=`echo $VALORI | awk '{ print $4 }'`
	TRKB=`echo $VALORI | awk '{ print $6 }'`

	TRAFFICO=$[ `iptables -Z -vnxL "ACCEPT_AND_COUNT_$IP" | tail -1 | awk '{ print $2 }'` / 1024 ]
	
	TRKB=$[ $TRMIN - $TRAFFICO ]
	TRMIN=$[ $TRMIN - 1 ]

	if [ "$TRKB" -lt 0 -o "$TRMIN" -lt 0 ] ; then
		ssh $IP -l $U "logout.sh"
	else     
		echo "dn: user=$U,dc=labammsis" > /tmp/modifica.ldif
		echo "TrafficoResiduoKB: $TRKB" >> /tmp/modifica.ldif
		echo "TempoResiduoMinuti: $TRMIN" >> /tmp/modifica.ldif		
		ldapmodify -h 10.1.1.254 -x -D  "cn=admin,dc=lab4,dc=ingbo" -w  admin -f tmp/modifica.ldif
		rm -f /tmp/modifica.ldif
	fi
done

