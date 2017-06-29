#!/bin/bash
if ! test "$1"
then
    echo Serve almeno un nome di file o directory da salvare
    exit 1
fi
    SERVER=`select.sh | cut -f2 -d' '`
if tar cf - "$@" | ssh $SERVER 'bserver.sh'
then
    echo "Completato con successo"
else
echo bclient.sh "$@" | at now + 1 hour
fi
