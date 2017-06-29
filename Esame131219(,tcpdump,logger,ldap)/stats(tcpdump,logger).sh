#!/bin/bash
#come garantire che lo script riceva automaticamente il segnale USR1 al minuto 10 di ogni ora
##### inserire con crontab -e questa riga
##### 10 * * * * /bin/pkill -SIGUSR1 stats.sh


################################################
# FUNZIONI
function logfun(){
    logger -p local6.notice $( cat /etc/ports.txt | sed -e 's/\n/ /g' )
    echo > /etc/ports.txt
}
################################################
# MAIN
trap log_fun SIGUSR1
echo > /etc/ports.txt
tcpdump -i eth1 -nlp tcp | awk '{ print $3 }' | cut -f5 -d. | while read PORT ; do
    if [ ! grep -q $PORT /etc/ports.txt ] then
        echo $PORT >> /etc/ports.txt
    fi

done

