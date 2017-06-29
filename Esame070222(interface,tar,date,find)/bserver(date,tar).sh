#!/bin/bash
USER=`whoami`
DATE=`date +%Y%m%d-%H%M`
mkdir -p /backups/$USER/$DATE
tar -C /backups/$USER/$DATE -x -f -
