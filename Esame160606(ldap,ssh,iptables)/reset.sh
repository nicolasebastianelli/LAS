#!/bin/bash

#####################################################################
###### FUNZIONI

function segnala_client(){
	# si collega al client e termina tutti i processi 
	# che stanno utilizzando socket di rete
	# l'output di ss può essere di questo tipo:
	# tcp ESTAB 0 0 127.0.0.1:ssh 127.0.0.1:37012 users:(("sshd",pid=10610,fd=3),("sshd",pid=10516,fd=3))
	# prima converto le virgole in a capo, poi seleziono i pid
        ssh root@$1 "ss -ptu | sed -e 's/,/\n/g' | grep pid= | sed -e 's/pid=//' | xargs kill -9"
}

function rimuovi_regole(){
	# rimuove su entrambi i router la relativa regola di logging inserita da check.sh
	# riutilizzo la stringa identificativa per rimuovere la regola
	# individuandone la posizione (vanno cancellate dall'ultima alla prima
	# altrimenti la prima cancellazione causa uno slittamento delle altre)
	iptables --line-numbers -vnL $2 | grep " check_$1 " | awk '{ print $1 }' | sort -nr | while read N ; do
		iptables -D $2 $N
	done
}


#####################################################################
###### MAIN

# Questo script esamina continuamente il file /var/log/orphans.log. 
# Per ogni riga che legge, determina se l'IP client in essa contenuto
# è stato osservato più di 10 volte nei due minuti precedenti.

tail -f /var/log/orphans.log | grep --line-buffered " check_" | while read riga ; do
	# check.sh marca le righe con la stringa check_INDIRIZZO, quindi		
        IP=$(echo $riga | awk -F 'check_' '{ print $2 }' | awk '{ print $1 }')

	# ricavo il timestamp e lo converto in secondi dall'1/1/70
	TS=$(echo $riga | awk '{ print $1,$2,$3 }')
	TS=$(date -D "$TS" +%s)

	# implemento su file un buffer circolare nel quale tenere 
	# gli ultimi 10 timestamp relativi all'indirizzo letto:
	# "dimentico" la riga più vecchia e accodo la più recente
	if test -f /tmp/buffer_$IP ; then
		tail -9 /tmp/buffer_$IP > /tmp/new_buffer_$IP
	else
		echo "0" > /tmp/new_buffer_$IP
	fi
	echo $TS >> /tmp/new_buffer_$IP
	mv /tmp/new_buffer_$IP /tmp/buffer_$IP

	# leggo il timestamp più vecchio, se è entro i 2 minuti
	# lo sono anche tutti gli altri --> ho superato la soglia
	FIRSTTS=$(head -1 /tmp/buffer_$IP)
        if test $(( $TS - $FIRSTTS )) -lt 120 ; then
                segnala_client $IP
                rimuovi_regole $IP INPUT
                rimuovi_regole $IP FORWARD
                rimuovi_regole $IP OUTPUT
        fi
done

