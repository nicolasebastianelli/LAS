#!/bin/bash

if [ "$(whoami)" != "root" ]
then
	echo "Need to be root"
	exit 1
fi

# adatto per l'ambiente di laboratorio
case `hostname` in 
	Router)	
		ROUTER=FAST
		;;
	Server) 
		ROUTER=CHEAP
		;;
	*) 
		echo "Not admitted on this host"
	   	exit 2
		;;
esac

CHEAP=192.168.56.203
FAST=192.168.56.202
CLIENT="192.168.56.211-192.168.56.219"

# REGOLE COMUNI
iptables -F

# Accetto il traffico sull'interfaccia locale
iptables -I INPUT -i lo -j ACCEPT
iptables -I OUTPUT -o lo -j ACCEPT

# Direttive per il logging dei pacchetti ICMP
grep -v /var/log/ping /etc/rsyslog.conf > /tmp/rsyslog.$$
echo -e "kern.warn\t\t/var/log/ping" >> /tmp/rsyslog.$$
cat /tmp/rsyslog.$$ > /etc/rsyslog.conf
/etc/init.d/rsyslog reload
iptables -I INPUT -i eth3 -m iprange --src-range $CLIENT -p icmp -j LOG --log-level warn --log-prefix " ping_request "

# consento ssh router->client
iptables -I OUTPUT -m iprange --dst-range $CLIENT -p tcp --dport 22 -j ACCEPT
iptables -I INPUT -m iprange --src-range $CLIENT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT


if test "$ROUTER" = "CHEAP" ; then

	# CHEAP consente sempre il forward
	iptables -I FORWARD -m iprange --src-range $CLIENT -j ACCEPT
	iptables -I FORWARD -m iprange --dst-range $CLIENT -j ACCEPT 

	# CHEAP è server LDAP per FAST
	iptables -I INPUT -i eth3 -s $FAST -d $CHEAP -p tcp --dport 389 -j ACCEPT
	iptables -I OUTPUT -o eth3 -d $FAST -s $CHEAP -p --sport 389 -m state --state ESTABLISHED -j ACCEPT
fi

if test "$ROUTER" = "FAST" ; then

	# FAST è client LDAP per CHEAP
	iptables -I OUTPUT -o eth3 -d $CHEAP -s $FAST -p tcp --dport 389 -j ACCEPT
	iptables -I INPUT -i eth3 -s $CHEAP -d $FAST -p tcp --sport 389 -m state --state ESTABLISHED -j ACCEPT

	# FAST è client SNMP verso i client
	iptables -I OUTPUT -s $FAST -m iprange --dst-range $CLIENT -p udp --dport 161 -j ACCEPT
	iptables -I INPUT -d $FAST -m iprange --src-range $CLIENT -p udp --sport 161 -m state --state ESTABLISHED,RELATED -j ACCEPT 
fi


# Tutto il resto e' scartato
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

