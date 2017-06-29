#!/bin/bash


# Per avviarlo all'avvio inserire nel file /etc/rc0.d /path/to/routerinit.sh start
# Per avviarlo allo spegnimento inserire nel file /etc/rc6.d /path/to/routerinit.sh stop
################################################
# FUNZIONI

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



################################################
# MAIN

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

if [ "$1" = "start" ] then

# sono server LDAP per i client
server "10.1.1.1-10.1.1.9" tcp 389

# sono client i server SNMP per l'altro router
client "10.1.1.1-10.1.1.9" udp 161

# sono server SYSLOG per i server
server $ALTRO udp 514

elif [ "$1" = "stop" ] then

iptables -F
fi







