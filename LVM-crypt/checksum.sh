#!/bin/bash

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

USER=$(echo $SUDO_USER)
FILE=$1
BASE=$2

echo "$(date)" >> $FILE

PTS=$(pvs --noheadings -o pv_name | sed 's/:.*//')
NUMPTS=$(pvs --noheadings | wc -l)
echo "Found $NUMPTS encrypted mappings."
for PT in $PTS
do
    echo $(sha512sum $PT) >> $FILE
done

NUMPTS=$(grep -c $BASE[0-9] /proc/partitions)
touch $FILE
echo "Found $NUMPTS partitions."
MAXNUMVOLS=128
i=3
while [ $i -lt $NUMPTS ]
do
    echo $(sha512sum /dev/$BASE$i) >> $FILE
    i=$(($i+1))
done
