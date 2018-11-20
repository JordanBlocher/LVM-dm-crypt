#!/bin/bash

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

if [ $# -ne 1 ]; 
    then printf "Usage:\n\t ./mount <partition>\n"
    exit 
fi

USER=$(echo $SUDO_USER)
BASE=$1

NUMPTS=13 #$(pvs --noheadings | wc -l)
i=1
while [ $i -lt $(($NUMPTS)) ]
do
    echo "Syncing /dev/$BASE$(($i+$NUMPTS)) from /dev/$BASE$(($i+2))"
    dd if=/dev/$BASE$(($i+2)) of=/dev/$BASE$(($i+$NUMPTS))
    i=$(($i+1))
done
