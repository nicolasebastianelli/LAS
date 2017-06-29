#!/bin/bash

if [ "$(whoami)" != "root" ]
then
	echo "Ricordati che devi lanciarmi come root..."
	exit
fi

iptables -F

# Accetto il traffico per poter usare i sistemi dall'host
iptables -A INPUT -i eth3 -j ACCEPT
iptables -A OUTPUT -o eth3 -j ACCEPT
# Accetto il traffico sull'interfaccia locale
iptables -I INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
# Tutto il resto e' scartato
iptables -P INPUT REJECT
iptables -P OUTPUT REJECT
iptables -P FORWARD REJECT

# Permetto solo le connessioni SNMP in uscita verso i client
iptables -A OUTPUT -d 10.1.1.0/24 -s 10.1.1.254 -p udp --dport 161 -j ACCEPT
# ... e relativi pacchetti di risposta alle connessioni gia stabilite
iptables -A INPUT -s 10.1.1.0/24 -d 10.1.1.254 -p udp --sport 161 -m state --state ESTABLISHED,RELATED -j ACCEPT 

# non servono regole per SSH, viene aperto da gate.sh

# poiche LDAP è sia ospitato che utilizzato in questo sistema
# le regole per l'interfaccia lo sono sufficienti a farlo funzionare

