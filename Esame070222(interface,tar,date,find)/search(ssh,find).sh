#!/bin/bash
select.sh | ( read USER SERVER

if [ "$1" = "file" ] && test "$2"
then
    ssh $SERVER "find /backups/$USER -name $2"
elif echo $1 | egrep -q '^[0-9]{8}-[0-9]{4}$'
    ssh $SERVER "find /backups/$USER/$1"
else
    echo "Parametri non corretti"
fi
)
