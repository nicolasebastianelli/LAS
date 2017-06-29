#!/bin/bash
# esame 2016-06-06 - check.sh 

################################################
# FUNZIONI

function is_default(){
	# segnalo che sta girando il verificatore
	touch running_$1
        ssh root@$1 "ip route" | grep -q "default via $ROUTER" || touch $1 
	rm -f running_$1
}

function imposta_regole(){
	# ... deve essere attivata (evitando duplicazioni) 
	# su entrambi i router una regola di iptables 
	# che permetta di loggare ogni pacchetto da e per tale client.
	echo "if ! iptables -vnL FORWARD | grep -q 'check_$1' ; then
                iptables -I FORWARD -s $1 -j LOG --log-level debug --log-prefix  ' check_$1 '
                iptables -I FORWARD -d $1 -j LOG --log-level debug --log-prefix  ' check_$1 '
                iptables -I INPUT -s $1 -j LOG --log-level debug --log-prefix  ' check_$1 '
                iptables -I OUTPUT -d $1 -j LOG --log-level debug --log-prefix  ' check_$1 '
              fi" > /tmp/regole$$.sh
	/bin/bash /tmp/regole$$.sh
	scp /tmp/regole$$.sh $ALTRO:/tmp
	ssh $ALTRO "/bin/bash /tmp/regole$$.sh ; rm -f /tmp/regole$$.sh"
	rm -f /tmp/regole$$.sh
}

#################################################
# MAIN

# Questo script rileva su quale router è in esecuzione
ROUTER=$(ifconfig eth2 | grep "inet addr" | awk -F 'addr:' '{ print $2 }' | cut -f1 -d" ")
if "$ROUTER" = "10.1.1.253" ; then ALTRO="10.1.1.254" 
elif "$ROUTER" = "10.1.1.254" ; then ALTRO="10.1.1.253" 
else echo "non sono su di un router" ; exit 1
fi

# con una query alla directory LDAP locale determina quali client lo stanno
# utilizzando come default gateway, e controlla via SSH su ognuno di essi 
# che effettivamente la configurazione del routing sia coerente. 
# Nel predisporre il controllo, si tenga conto del numero elevato di client,
# e si garantisca che possano essere raccolte tutte le risposte nel giro di 
# pochi secondi.

rm -rf /tmp/check$$
mkdir /tmp/check$$
cd /tmp/check$$

ldapsearch -h 127.0.0.1 -x -b 'dc=labammsis' "(&(objectClass=gw)(iprouter=$ROUTER))" -s one ipclient | grep "^ipclient:" | awk '{ print $2 }' | while read IP ; do
	# lancio tutti i verificatori di coerenza in parallelo
        is_default $IP &
	# crea un file in /tmp/check$$ per ogni client con routing incoerente
done


# attendo la fine di tutti i verificatori
while ls running* ; do sleep 1 ; done > /dev/null 2>&1

# Per ogni client su cui è configurato un default gateway incoerente 
# con quello memorizzato in LDAP ...
for CLIENT in * ; do
	imposta_regole $CLIENT
done


# Indicare nei commenti:
# come eseguire automaticamente lo script ogni 5 minuti;
#
##### inserire con crontab -e questa riga
##### */5 * * * * /pathto/check.sh
#
# come predisporre i sistemi perché i router possano eseguire comandi sui client;
#
##### generare sui router coppie di chiavi ssh
##### mettere le chiavi pubbliche dei router su ogni client
##### nel file /root/.ssh/authorized_keys
#
# come configurare il sistema di logging perché ogni messaggio
# di iptables generato su ognuno dei router venga scritto sul 
# file /var/log/orphans.log di entrambi i router.
#
##### inserire nel file /etc/rsyslog.conf di 10.1.1.253 
##### l'abilitazione alla ricezione udp e queste regole:
#####  kern.=debug	/var/log/orphans.log
#####  kern.=debug	@10.1.1.254
##### inserire nel file /etc/rsyslog.conf di 10.1.1.254 
##### l'abilitazione alla ricezione udp e queste regole:
#####  kern.=debug	/var/log/orphans.log
#####  kern.=debug	@10.1.1.253
