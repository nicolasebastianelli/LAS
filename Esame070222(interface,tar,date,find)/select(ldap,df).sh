#!/bin/ bash
USER=`whoami`
SERVER=`ldapsearch -h 172.16.0.1 -x -b 'dc=lab4,dc=ingbo' -s one "(&(objectClass=bserver)(Username=$USER))" | grep ServerIP | awk -F ': ' '{ print $2 }'`

if ! test "$SERVER"
then
    MINUSE=100
    SERVER=""
    for S in `seq 11 15`
    do
        USE=`ssh 172.17.0.$S "df | egrep '/backups$' | awk '{ print \$5 }' | sed -e 's/%//'`
        if [ $USE -lt $MINUSE ] ; then MINUSE=$USE ; SERVER=$S ; fi
    done
    echo "dn: Username=$USER,dc=lab4,dc=ingbo" > /tmp/ldif$$
    echo "objectClass: bserver" >> /tmp/ldif$$
    echo "Username: $USER" >> /tmp/ldif$$
    echo "ServerIP: $SERVER" >> /tmp/ldif$$
    ldapadd -h 172.16.0.1 -x -D "cn=admin,dc=lab4,dc=ingbo" -w admin -f /tmp/ldif$$
    rm -f /tmp/ldif$$
fi

echo $USER $SERVER
