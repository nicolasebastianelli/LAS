#!/bin/bash

ROUTER1="10.1.1.253"
ROUTER2="10.1.1.254"
IPCLIENT=$(ifconfig eth2 | grep "inet addr" | awk -F 'addr:' '{ print $2 }' | cut -f1 -d" ")

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

function registra_ldap(){
	# $1 = nuovo gw
	# $2 = server LDAP da aggiornare
	ldapdelete -c -h $2 -x -D "cn=admin,dc=labammsis" -w admin "dn: ipclient=$IPCLIENT,dc=labammsis" 2> /dev/null
	TS=$(/bin/date +%s)
        echo "dn: ipclient=$IPCLIENT,dc=labammsis
objectClass: gw
ipclient: $IPCLIENT
iprouter: $1
timestamp: $TS" | ldapadd -x -D "cn=admin,dc=labammsis" -w admin -h $2
}


function imposta_default(){
        ip route replace default via $1

	# Ogni volta che lo script effettua una scelta di default gateway, 
	# tenta di registrarla su entrambe le directory LDAP, assicurandosi
	# che l'entry che riguarda il proprio client sia unica.
	
        registra_ldap $1 $ROUTER1
        registra_ldap $1 $ROUTER2
}

################################################
# MAIN

# Questo script interroga una directory LDAP per determinare quale
# dei due router ha il minor numero di client che lo stanno utilizzando, 
# e impostarlo poi come default gateway del client su cui viene lanciato.
# La query può essere fatta su R1 o su R2 indifferentemente;
# suggerimento: si noti che se il primo non risponde non ha senso 
# impostarlo come gateway.


MIN=$(ldapsearch -x -s sub -h 10.1.1.253 -b "dc=labammsis" "(objectClass=gw)" | grep "^iprouter: " | awk '{ print $2 }' | sort | uniq -c | sort -n | head -1 | awk '{ print $2 }')

if test -z "$MIN" ; then MIN=10.1.1.254 ; fi

imposta_default $MIN

# Successivamente lo script non termina, ma inizia a inviare un "ping"
# ogni secondo al gateway prescelto, e nel caso non riceva risposta 
# per tre volte consecutive commuta il default gateway sull'altro router,
# proseguendo con lo stesso tipo di monitoraggio sul nuovo gateway.

FAILPING="0"
while sleep 1 ; do
        if ping -c 1 -W 1 "$MIN" > /dev/null 2>&1 ; then
		FAILPING=0
	else		
                FAILPING=$(( $FAILPING + 1 ))
                if test $FAILPING -eq 3 ; then
                        MIN=$(altro_router $MIN)
                        imposta_default $MIN
                        FAILPING="0"
                fi
        fi
done

