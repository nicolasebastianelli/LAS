#!/bin/bash

# Per avviare lo script ogni 10 minuti inserire nel file /etc/crontab la seguente riga
#*/10 *  * * *   root    /home/las/reset.sh

ldapsearch -x -c -s one -h 10.9.9.254 -b "dc=laboratorio" "objectClass=risorse" | egrep "^dn: " | awk '{ print $2 }' | while read DN
do
	echo "dn: $DN"
	echo "changetype: modify"
	echo "replace: traffico"
	echo "traffico: 0"
	echo ""
done | ldapmodify -x -c -h 10.9.9.254 -w las -D "cn=admin,dc=laboratorio"

