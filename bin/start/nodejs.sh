#!/bin/sh

LOG=/home/calicobill/nodejs/log
cd /home/calicobill/nodejs
forever start -a -l $LOG -o $LOG -e $LOG index.js 
