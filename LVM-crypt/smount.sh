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

#printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
#read BASE
BASE=$1

mkdir -p /mnt/crypt
cryptsetup plainOpen --allow-discards -d ~/.ssh/dm-key.pub /dev/$BASE"2" dm-keys
mount /dev/mapper/dm-keys /mnt/crypt

NUMPTS=$(grep -c $BASE[0-9] /proc/partitions)

mkdir -p /mnt/storage
echo "Found $NUMPTS partitions."
MAXNUMVOLS=128
i=3
idx=1
while [ $i -lt $(($NUMPTS+1)) ]
do
    UUID=$(echo blkid -s UUID -o value /dev/$BASE$i)
    if [ ! -f /mnt/crypt/key$(($i-2)) ]
    then
        echo "Loading storage/pt$idx from /dev/$BASE$i"
        mkdir -p /mnt/storage/pt$idx
        mount /dev/$BASE$i /mnt/storage/pt$idx -t ext4
        idx=$(($idx+1))
    fi
    i=$(($i+1))
done

umount /mnt/crypt
cryptsetup close dm-keys
