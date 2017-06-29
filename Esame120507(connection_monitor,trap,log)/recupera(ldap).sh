#!/bin/bash

NOME_FILE="$1"
CLIENT=$( echo $SSH_CLIENT | awk '{ print $1 }' )
UTENTE=$( whoami )

# Trasferisco il file
if get $NOME_FILE ; then

	# il comportamento di default di ssh ci aiuta
	# usa l'utente che ha lanciato recupera.sh (quindi lo stesso di richiedi.sh)
	# colloca il file nella sua home dir
	scp "$NOME_FILE" $CLIENT:

	# Trovo la dimensione del file
	DIMENSIONE=$( stat "$NOME_FILE" | egrep "Size:" | awk '{ print $2 }' )

	# uso una subshell per raccogliere direttamente su di un unico STDOUT 
	# tutti gli echo e poterli poi inviare in pipe a ldapmodify
	(
	echo "dn: ut=$UTENTE,dc=laboratorio"

	TRAFFICO=$(ldapsearch -x -c -h 10.9.9.254 -b "dc=laboratorio" "utente=$1" | grep "^traffico: " | cut -d' ' -f2-)

	if [ "$TRAFFICO" ]
	then
		DIMENSIONE=$(($DIMENSIONE + $TRAFFICO))
		echo "changetype: modify"
		echo "replace: traffico"
		echo "traffico: $DIMENSIONE"
	else
		echo "changetype: add"
		echo "objectClass: risorse"
		echo "utente: $UTENTE"
		echo "traffico: $DIMENSIONE"
	fi
	) | ldapmodify -x -c -h 10.9.9.254 -w las -D "cn=admin,dc=laboratorio" 
fi

