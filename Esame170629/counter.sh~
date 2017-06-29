#!/bin/bash

iptables -L | while read RIGA ; do
	CHAIN = $(echo $RIGA |  awk '{ print $2 }')
	TRAFFICO=$(iptables -Z -vnxL "$CHAIN" | tail -1 | awk '{ print $2 }')
	PORT = $(echo $CHAIN | awk -F'_' '{ print $2 }')
	echo "$PORT:$TRAFFICO"
done
