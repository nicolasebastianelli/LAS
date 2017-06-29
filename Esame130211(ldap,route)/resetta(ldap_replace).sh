#!/bin/bash

# Per avviare lo script ogni ora inserire nel file /etc/crontab la seguente riga
# 0 * * * *   root    /home/las/resetta.sh

ldapsearch -x -c -s one -h 192.168.56.203 -b "dc=labammsis" "objectClass=consumi" | egrep "^dn: " | while read DN
do
	echo "$DN"
	echo "changetype: modify"
	echo "replace: traffico"
	echo "traffico: 0"
	echo ""
done | ldapmodify -x -c -h 192.168.56.203 -w las -D "cn=admin,dc=labammsis"

