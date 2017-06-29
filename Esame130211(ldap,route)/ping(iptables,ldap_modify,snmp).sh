#!/bin/bash

#  deve essere permanentemente in esecuzione su entrambi i router (specificare nei commenti come si può ottenere che questo avvenga fin dal boot

# inserire in /etc/inittab
# pi:2345:respawn:/path/to/ping.sh

if [ "$(whoami)" != "root" ]
then
	echo "Need to be root"
	exit
fi

ROUTER=`hostname`
SOGLIA=$(10 * 1024 * 1024)

# funzione che abilita il traffico per uno specifico client i parametri sono $1: indirizzo cliente $2: inserimento o cancellazione regole
function set_rules()
{

if [ "$2" = "open"] ; then

	# Apro la connessione inserendo una catena per contare il traffico
	iptables -N "C_$1" 
	iptables -I "C_$1" -j ACCEPT

	iptables -I FORWARD -i eth3 -s "$1" -j "C_$1"
	iptables -I FORWARD -o eth3 -d "$1" -j "C_$1"

elif [ "$2" = "close" ] ; then 

	# Rimuovo la connessione
	iptables -D FORWARD -i eth3 -s "$1" -j "C_$1"
	iptables -D FORWARD -o eth3 -d "$1" -j "C_$1"

	iptables -F "C_$1" 
	iptables -X "C_$1"
	
fi

}

# funzione che calcola utente client che ha effettuato il ping; parametri $1: indirizzo dell'agent SNMP (cioe' del client che richiede la connessione)
function find_user_snmp()
{
	snmpget -v 1 -c public -OQn "$1" .1.3.6.1.4.1.2021.60.4.1.2.5.101.115.97.109.101.1 | awk -F' = ' '{ print $2 }' | sed -e 's/"//g'
}

# funzione che cerca sulla directory LDAP se esiste l'albero per l'utente specificato
function get_user_traffic_ldap()
{
	ldapsearch -x -c -h 192.168.56.203 -s base -b "utente=$1,dc=labammsis"  | grep "^traffico: " | cut -d' ' -f2-
}

# vado a leggere i ping loggati
tail -f /var/log/pings | egrep --line-buffered ' ping_request ' | while read line ; do
# ricavo l'indirizzo sorgente
SOURCE=$( echo "$line" | awk -F 'SRC=' '{ print $2 }' | cut -d' ' -f1 )

	case "$ROUTER" in 
	Server)
		
	#CHEAP imposto default gw a Router e lascio regole di firewall come stanno
	ssh root@$SOURCE "route del default ; route add default gw 192.168.56.203"
		;;

	Router)
	#FAST
		UTENTE=$( find_user_snmp "$SOURCE" )
		TRAFFICO=$( get_user_traffic_ldap "$UTENTE" )
		
		# se non esiste nessuna entry LDAP per questo utente la crea e abilito la connessione		
		if [ -z "$TRAFFICO" ]
		then
			(echo "dn: utente=$UTENTE,dc=labammsis"
			echo "changetype: add"
			echo "objectClass: consumi"
			echo "utente: $UTENTE"
			echo "traffico: 0") 
			| ldapmodify -x -c -h 192.168.56.203 -w las -D "cn=admin,dc=labammsis" 
		# se esiste l'entry e il traffico non ha superato la soglia
			TRAFFICO=0
		fi

		if [ "$TRAFFICO" -lt "$SOGLIA"]
		then
		# imposto default gw a FAST
		ssh root@$SOURCE "route del default ; route add default gw 192.168.56.202"
		
		# abilitare le connessioni se sono già abilitato aggiorno LDAP
		
		DIMENSIONE=$(iptables -Z -vxnL C_$SOURCE | grep ACCEPT | awk '{ print $2 }' 2>/dev/null)

		if [ -z "$DIMENSIONE" ] ; then
			set_rules $SOURCE open
			DIMENSIONE=0
		else
			# aggiorno la dir di LDAP
			DIMENSIONE=$(($DIMENSIONE + $TRAFFICO))
			(echo "dn: utente=$UTENTE,dc=labammsis"
			 echo "changetype: modify"
			 echo "replace: traffico"
			 echo "traffico: $DIMENSIONE") 
			| ldapmodify -x -c -h 192.168.56.202 -w las -D "cn=admin,dc=laboratorio" 
		fi

		# se esiste l'entry ma il traffico ha già superato la soglia
		if [ "$DIMENSIONE" -gt "$SOGLIA"]
		then
		# setto default gateway a CHEAP	
		ssh root@$SOURCE "route del default; route add default gw 192.168.56.203"
		#rimuovo le regole	
		set_rules "$SOURCE" close

		fi
		;;

	*)
		echo "Who is using this script?"
		exit 1
		;;
	esac

done

