#!/bin/bash

# configurazione delle interfacce, ad esempio un alias di eth1 sulla rete client ed un alias di eth2 sulla rete server
ifconfig eth1:1 172.16.0.1 netmask 255.255.0.0 broadcast 172.16.255.255
ifconfig eth2:1 172.17.0.1 netmask 255.255.0.0 broadcast 172.17.255.255

# su linux non serve configurare esplicitamente il routing, sarebbe:
# route add -net 172.16.0.0 netmask 255.255.0.0 dev eth1
# route add -net 172.17.0.0 netmask 255.255.0.0 dev eth2

# firewall: accetta connessioni LDAP dai client...
iptables -I INPUT -p tcp --dport 389 -s 172.16.0.0/16 -j ACCEPT
iptables -I OUTPUT -p tcp --sport 389 -d 172.16.0.0/16 -j ACCEPT
# ... inoltra il traffico ssh tra client e server ...
iptables -I FORWARD -p tcp --dport 22 -s 172.16.0.0/16 -d 172.17.0.0/16 -j ACCEPT
iptables -I FORWARD -p tcp --sport 22 -d 172.16.0.0/16 -s 172.17.0.0/16 ! --syn -j ACCEPT
# ... consente tutto il traffico locale
iptables -I INPUT -i lo -j ACCEPT
iptables -I OUTPUT -o lo -j ACCEPT
# ... blocca tutto di default
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
