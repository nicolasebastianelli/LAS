#!/bin/bash

io=`whoami`
ps U "$io" | grep -v "^$$" | awk '{ print $1 }' | xargs kill
sleep 5
ps U "$io" | grep -v "^$$" | awk '{ print $1 }' | xargs kill -9 


filename=`date +%s`.tgz
tar -C $HOME -czpf - * | ssh 10.1.1.254 "cat > /users/'$io'/$filename"

echo "dn: user=$io,dc=labammsis" > /tmp/modifica.ldif
echo "Stato: Disconnesso" >> /tmp/modifica.ldif	
ldapmodify -h 10.1.1.254 -x  -D  "cn=admin,dc=labammsis" -w  admin -f tmp/modifica.ldif
rm -f /tmp/modifica.ldif	 

