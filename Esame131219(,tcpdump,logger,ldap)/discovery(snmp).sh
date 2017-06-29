#!/bin/bash


# Per avviarlo all'avvio inserire nel file /etc/rc0.d /path/to/routerinit.sh start
# Per avviarlo allo spegnimento inserire nel file /etc/rc6.d /path/to/routerinit.sh stop

################################################
# FUNZIONI

function find_user_snmp()
{
snmpget -v 1 -c public -OQn "$1" .1.3.6.1.4.1.2021.60.4.1.2.5.101.115.97.109.101.1 | awk -F' = ' '{ print $2 }' | sed -e 's/"//g'
}



################################################
# MAIN

echo > "/tmp/discovery/user$1.txt"

find_user_snmp | uniq | (while read NAME UID ; do
    if [ UID -gt 999 ] then
        echo "$NAME $UID" >> "/tmp/discovery/user$1.txt"
    fi
done)







