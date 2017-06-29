#!/bin/bash

###########################################################
###
### Funzioni
###
###########################################################



function track_start()
{
	echo "Inizializzazione logging"

	# Copio rsyslog.conf ripulito delle righe relative al monitoraggio
	egrep -v /var/log/newconn /etc/rsyslog.conf > "/tmp/rsyslog.conf.$$"
	# Accodo le direttive per il logging dei pacchetti di inizio/fine connessione e riavvio rsyslog
	echo -e "kern.warn\t\t/var/log/newconn" >> /etc/rsyslog.conf
	cat /dev/null > /var/log/newconn
	/etc/init.d/rsyslog restart

	# Inserisco nel packet filter le regole per loggare i pacchetti di inizio/fine connessione
	iptables -I FORWARD -s 10.1.1.0/24 -d 10.9.9.0/24 -p tcp --dport 22 --tcp-flags SYN,ACK,ACK SYN -j LOG --log-level warn --log-prefix " INIZIO "
	iptables -I FORWARD -s 10.1.1.0/24 -d 10.9.9.0/24 -p tcp --dport 22 --tcp-flags FIN FIN -j LOG --log-level warn --log-prefix " FINE "
}

function track_stop()
{
	echo "Termine del logging"
	# Rimuovo dal packet filter le regole per loggare i pacchetti
	iptables -D FORWARD -s 10.1.1.0/24 -d 10.9.9.0/24 -p tcp --dport 22 --tcp-flags SYN,ACK,ACK SYN -j LOG --log-level warn --log-prefix " INIZIO "
	iptables -D FORWARD -s 10.1.1.0/24 -d 10.9.9.0/24 -p tcp --dport 22 --tcp-flags FIN FIN -j LOG --log-level warn --log-prefix " FINE "

	iptables -nL | egrep "^Chain CONN_" | awk -F '_' '{ print $2,$3,$4,$5 }'  | while read SRC SPT DST DPT ALTRO;
	do
		track_conn "FINE" "$SRC" "$SPT" "$DST" "$DPT"
	done

	# Ripristino la configurazione originale di rsyslog
	cat "/tmp/rsyslog.conf.$$" > /etc/rsyslog.conf
	/etc/init.d/rsyslog restart
	#rm /var/log/newconn
}


# Argomenti:
# $1: comando iptables I/D
# $2: ip sorgente
# $3: porta sorgente
# $4: ip sorgente
# $5: porta destinazione
# $6: catena custom
function manage_rules()
{
	# pacchetti di richiedi.sh (ssh da $2 a $4)
	iptables -$1 FORWARD -p tcp -s "$2" --sport "$3" -d "$4" --dport "$5" -j "$6"
	iptables -$1 FORWARD -p tcp -s "$4" --sport "$5" -d "$2" --dport "$3" -m state --state ESTABLISHED -j "$6"

	# pacchetti di recupera.sh (ssh da $4 a $2, non posso conoscere la porta sorgente)
	iptables -$1 FORWARD -p tcp -s "$4" -d "$2" --dport 22 -j "$6"
	iptables -$1 FORWARD -p tcp -s "$2" --sport 22 -d "$4" -m state --state ESTABLISHED -j "$6"
}	



# Argomenti:
# $1: tipo di azione INIZIO/FINE
# $2: ip sorgente
# $3: porta sorgente
# $4: ip sorgente
# $5: porta destinazione
function track_conn()
{
	CONN="CONN_$2_$3_$4_$5"
	if [ "$1" = "INIZIO" ]
	then
		if ! iptables -nL "$CONN" > /dev/null 2>&1
		then
			echo "Abilito connessione $CONN"
			iptables -N "$CONN"
			manage_rules I $2 $3 $4 $5 $CONN
			iptables -I "$CONN" -j ACCEPT
		fi
	elif [ "$1" = "FINE" ]
	then
		if iptables -nL "$CONN" > /dev/null 2>&1
		then
			echo "Disattivo connessione $CONN"
			manage_rules D $2 $3 $4 $5 $CONN
			iptables -F "$CONN"
			iptables -X "$CONN"
		fi
	fi
}



# Argomenti:
# $1: indirizzo dell'agent SNMP (cioe' del client che richiede la connessione)
function find_user_snmp()
{
	snmpget -v 1 -c public -OQn "$1" .1.3.6.1.4.1.2021.60.4.1.2.5.101.115.97.109.101.1 | awk -F' = ' '{ print $2 }' | sed -e 's/"//g'
}



# Argomenti:
# $1: nome dell'utente da cercare
function get_user_traffic_ldap()
{
	ldapsearch -x -c -h 10.9.9.254 -b "dc=laboratorio" "utente=$1" | grep "^traffico: " | cut -d' ' -f2-
}



#############################################################################
###
### MAIN
###
#############################################################################

if [ "$(whoami)" != "root" ]
then
	echo "Ricordati che devi lanciarmi come root..."
	exit
fi

TMAX=$[ 20 * 1024 * 1024 ]

# Termine e pulizia alla pressione di Ctrl+C
trap track_stop SIGINT

# Avvio monitoraggio
track_start

# Ad ogni aggiornamento del log guardo se consentire od eliminare una connessione
tail -f /var/log/newconn | egrep --line-buffered ' (INIZIO|FINE) ' | while read LINEA
do
	TIPO=$( echo "$LINEA" | awk -F ']  ' '{ print $2 }' | cut -d' ' -f1 )
	SRC_ADDR=$( echo "$LINEA" | awk -F 'SRC=' '{ print $2 }' | cut -d' ' -f1 )
	SRC_PORT=$( echo "$LINEA" | awk -F 'SPT=' '{ print $2 }' | cut -d' ' -f1 )
	DST_ADDR=$( echo "$LINEA" | awk -F 'DST=' '{ print $2 }' | cut -d' ' -f1 )
	DST_PORT=$( echo "$LINEA" | awk -F 'DPT=' '{ print $2 }' | cut -d' ' -f1 )

	echo "Elaboro nuovo evento di connessione: $TIPO"

	if [ "$TIPO" = "INIZIO" ]
	then
		echo "Indirizzo che richiede la connessione: $SRC_ADDR"
		UTENTE=$( find_user_snmp "$SRC_ADDR" )

		echo "Utente che richiede la connessione su '$SRC_ADDR': $UTENTE"
		TRAFFICO=$( get_user_traffic_ldap "$UTENTE" )

		echo "Traffico gia utilizzato da '$UTENTE': $TRAFFICO"

		if [ $TRAFFICO -ge $TMAX ]
		then
			echo "L'utente '$UTENTE' ha generato troppo traffico"
			break;
		fi 
	fi
	track_conn "$TIPO" "$SRC_ADDR" "$SRC_PORT" "$DST_ADDR" "$DST_PORT"
done

