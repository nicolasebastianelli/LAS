#!/bin/bash

ROUTER1="10.1.1.253"
ROUTER2="10.1.1.254"

################################################
# FUNZIONI

function altro_router(){
        ATTUALE=$1
        if test $ATTUALE = $ROUTER1
                echo $ROUTER2
        else
                echo $ROUTER1
        fi
}

function setipparams() {
	# setta le variabili a seconda che ci sia un ip o un range
	# MOD per caricare eventualmente il modulo iprange
	# IPS e IPD sono sorgente e destinazione con l'opzione giusta
	if echo $1 | grep -q -- '-' ; then
		# se c'è un - è un range
		MOD="-m iprange"
		IPD="--dst-range $1"
		IPS="--src-range $1"
	else
		# se no è un ip singolo
		MOD=""
		IPD="-d $1"
		IPS="-s $1"
	fi
}

function setprotoparams() {
	# setta le variabili a seconda del protocollo (icmp, tcp o udp)
	# PROTO è sempre il protocollo
	# DP e SP sono sorgente e destinazione solo se non è icmp
	# sarebbe opportuno error checking, anche se invocata solo 
	# internamente da questo stesso script
	PROTO="$1"
	if test "$PROTO" = "icmp" ; then
		DP=""
		SP=""
	else
		DP="--dport $2"
		SP="--sport $2"
	fi
}
	
function client() {
	# imposta regole iptables quando io sono client
	# parametri: server proto porta 
	setipparams $1
	setprotoparams $2 $3
	iptables -I OUTPUT $MOD $PROTO $DP $IPD -j ACCEPT
	iptables -I INPUT $MOD $PROTO $SP $IPS --state ESTABLISHED -j ACCEPT
}

function server() {
	# imposta regole iptables quando io sono server
	# parametri: client proto porta 
	setipparams $1
	setprotoparams $2 $3
	iptables -I INPUT $MOD $PROTO $DP $IPS -j ACCEPT
	iptables -I OUTPUT $MOD $PROTO $SP $IPD --state ESTABLISHED -j ACCEPT
}

function init_non_in_esecuzione(){
	# cerco nella process table la riga relativa a "proc init.sh"
	R=$(snmpwalk -v 1 -c public localhost UCD-SNMP-MIB::prTable | grep init.sh | awk -F 'prNames.' '{ print $2 }' | awk '{ print $1 }')

	# verifico lo stato dell'ErrMessage, e ritorno un exit code
	# coerente col nome della funzione (true se non in esecuzione)
        snmpget -v 1 -c public localhost "UCD-SNMP-MIB::prErrMessage.$R" | grep -q "No init.sh process running"
}

function sostituisci_ldap(){
        #cancello le entry che ci sono...
        ldapsearch -h $ATTUALE -x -s sub -b "dc=labammsis" "objectClass=gw" | grep "^dn: " | awk '{ print $2 }' | rev | sort -r | rev | ldapdelete -D "cn=admin,dc=labammsis" -w "admin" -x
        #le rimpiazzo con le entry dell'altro router
        ldapsearch -x -c -s sub -h $ALTRO -b "dc=labammsis" "objectClass=gw" | ldapadd -x -D "cn=admin,dc=labammsis" -w admin 
}



################################################
# MAIN

ATTUALE=$(ifconfig eth2 | grep "inet addr" | awk -F 'addr:' '{ print $2 }' | cut -f1 -d" ")
ALTRO=$(altro_router $ATTUALE)

# configurare il packet filter locale per consentire solo il traffico 
# necessario ai vari script di questo testo

iptables -F

# consento il traffico sull'interfaccia locale
iptables -I INPUT -i lo -j ACCEPT
iptables -I OUTPUT -o lo -j ACCEPT
#cambio la policy a default
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# sono server LDAP per i client (gw.sh)
server "10.1.1.1-10.1.1.200" tcp 389

# rispondo ai ping dei client (gw.sh)
server "10.1.1.1-10.1.1.200" icmp

# sono client SSH verso i client (check.sh e reset.sh)
client "10.1.1.1-10.1.1.200" tcp 22

# sono client e server SSH per l'altro router (check.sh e reset.sh)
client $ALTRO tcp 22
server $ALTRO tcp 22

# sono client e server SYSLOG per l'altro router (check.sh)
client $ALTRO udp 514
server $ALTRO udp 514

# sono client e server LDAP per l'altro router (init.sh)
client $ALTRO tcp 389
server $ALTRO tcp 389

# sono client i server SNMP per l'altro router (init.sh)
client $ALTRO udp 161
server $ALTRO udp 161


#se init non è in esecuzione allora sostituisco ldap
init_non_in_esecuzione && sostituisci_ldap

# Indicare nei commenti come configurare gli agenti SNMP dei router 
# per consentire il controllo.
#
# inserisco in snmpd.conf dei router 
#
# proc init.sh
#
# dopo aver configurato community e view per rendere visibile 
# l'intero MIB o la tabella UCD-SNMP-MIB







