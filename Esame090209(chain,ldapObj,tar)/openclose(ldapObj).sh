#! /bin/bash
#
# tengo traccia dello stato all'ultima esecuzione per mezzo di un file nel formato UTENTE STATO

ldapsearch -h 10.1.1.254 -x -s sub -b "dc=labammsis" "objectClass=utente" | while read RIGA ; do
	
	if echo "$RIGA" | grep -q '^dn:' ; then
		# uso dn perchè viene certamente prima di Stato
		# dn: user=nomeutente,dc=lab4,dc=ingbo
		USER=`echo "$RIGA" | cut -f2 -d= | cut -f1 -d,`
	elif echo "$RIGA" | grep -q '^Stato: ' ; then
		# Stato: connesso
		STATO=`echo $RIGA | awk '{ print $2 }'`
		echo "$USER $STATO" >> /tmp/stato-utenti.new

		if ! grep -q "^$USER $STATO$" /tmp/stato-utenti ; then
			
			IP=`ldapsearch -h 10.1.1.254 -x -s base -b "user=$USER,dc=labammsis" | grep "^Ip: " | awk '{ print $2 }'`
			if [ "$STATO" = "connesso" ] ; then
				fw.sh $IP open
			elif [ "$STATO" = "disconnesso" ] ; then
				fw.sh $IP close
			else
				echo Errore inaspettato: "$USER $STATO"
			fi
		fi
	fi
done

mv /tmp/stato-utenti.new /tmp/stato-utenti
