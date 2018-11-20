#!/bin/bash

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

USER=$(echo $SUDO_USER)

printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
read BASE

cd /home/$USER

mkdir -p workload

NUMFILES=50
while [ $NUMFILES -gt 1 ]
do
    SIZEFILE=$((50 / $NUMFILES))
    echo "Testing $NUMFILES files of size $SIZEFILE"
    ./mount.sh $BASE "before.sum"
    wait 
    rm /media/$USER/crypt/*
    ./umount.sh $BASE "after.sum"
    wait
    ./mount.sh $BASE "/home/$USER/workload/${NUMFILES}-${SIZEFILE}M_before.sum"
    wait
    cd /media/$USER/crypt
    j=1
    while [ $j -lt $NUMFILES ]
    do
        dd if=/dev/random of="${NUMFILES}-${j}-${SIZEFILE}MB" bs=$SIZEFILE"M" count=1
        wait 
        j=$(($j+1))
    done
    cd /home/$USER
    ./umount.sh $BASE "/home/$USER/workload/${NUMFILES}-${SIZEFILE}M_after.sum"
    wait %1
    NUMFILES=$(($NUMFILES-1))
done

chmod -R 0777 workload
