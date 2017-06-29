#!/bin/bash


# Recupero il nome del file
NOME_FILE=${1:?"Indicare il nome del file"}

# Genero un numero random tra 1 e 9
SERVER=$(( $RANDOM % 9 +1))

# Il flag -f di ssh lo manda in background
# di default mi connetto al server con lo stesso utente che lancia ssh sul client

if ! ssh -f $SERVER "/home/las/recupera.sh $NOME_FILE" 2> /dev/null
then
	echo "Impossibile stabilire la connessione con il server, riprova tra 10 minuti"
	exit 1
fi

TIMEOUT=300
SLEEP=10

# Aspetto di vedere il file e avviso l'utente
while [ "$TIMEOUT" -gt 0 ]
do
	if test -e "$NOME_FILE"
	then
		echo "File trasferito con successo"
		exit 0
	fi

	sleep $SLEEP
	TIMEOUT=$[ $TIMEOUT - $SLEEP ]
done

echo "Ho atteso inutilmente $TIMEOUT secondi la comparsa di $NOME_FILE"
exit 2


