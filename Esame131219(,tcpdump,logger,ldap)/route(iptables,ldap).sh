#!/bin/bash

# per avere il cliente costantemente in esecuzione utilizzo un while true
# per garantire affidabilità anche in caso di guasti inserisco in /etc/inittab pi:2345:respawn:/path/to/route.sh

CLIENTS=(10.1.1.1 10.1.1.2 10.1.1.3 10.1.1.4 10.1.1.5 10.1.1.6 10.1.1.7 10.1.1.8 10.1.1.9)
################################################
# FUNZIONI
function get_user_traffic_ldap()
{
    ldapsearch -x -c -s base -b "utente=$1,dc=labammsis"  | grep "^server: " | cut -d' ' -f2-
}

function set_iptables(){
    iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
    iptables -t nat -A POSTROUTING -m owner --uid-owner "$1" -i eth2 -j DNAT --to "$2"
}

################################################
# MAIN

while true ; do
    mkdir "/tmp/discovery"
    echo ${CLIENTS[*]} | sed -e 's/ /\n/g' | while read CLIENT ; do
        discovery.sh $CLIENT
    done
    cd /tmp/discovery
    for FILE in * ; do
        cat "$FILE" | while read USER UID ;do
            get_user_traffic_ldap "$USER" | sed -e 's/-/\n/g' | while read SERVER ; do
                set_iptables() $UID $SERVER
            done
        done
    done
    rm -rf "/tmp/discovery"
done

