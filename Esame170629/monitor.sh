#!/bin/bash


function find_traffic_snmp()
{
	snmpget -v 1 -c public -OQn "$1" .1.3.6.1.4.1.2021.60.4.1.2.5.101.115.97.109.101.1 | awk -F' = ' '{ print $2 }' | sed -e 's/"//g'
}

cat "/root/up.server.list" | while read SERVER ; do
	find_traffic_snmp() "$SERVER" | while read PORTATRAFFICO; do	
		echo "dn:admin,dc=labammsis" > /tmp/modifica.ldif
		echo "objectClass: traffic" >> /tmp/modifica.ldif
		echo "address: $SERVER" >> /tmp/modifica.ldif	
		echo "port_bytes: $PORTATRAFFICO" >> /tmp/modifica.ldif	
		NOW = $(date +%s)
		echo "timestamp: $NOW" >> /tmp/modifica.ldif	
		ldapadd -x -D  "cn=admin,dc=labammsis" -w  admin -f /tmp/modifica.ldif
		logger -p local0.info $(cat /tmp/modifica.ldif)
	done
done

#Syslog: inserire nel file /etc/rsyslog.conf di M1
#####  l’abilitazione alla ricezione udp e queste regole:
#####  local0.info	@10.1.1.2
##### inserire nel file /etc/rsyslog.conf di M2
##### l'abilitazione alla ricezione udp e queste regole:
#####  local0.info	/var/log/packets.log

# Cron:per eseguire uno script ogni 15 inserire con crontab -e questa la riga */15 * * * * /pathto/monitor.sh
