#!/bin/bash

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

if [ $# -ne 2 ]; 
    then printf "Usage:\n\t ./mount <partition> <filename>\n"
    exit 
fi

USER=$(echo $SUDO_USER)

#printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
#read BASE
BASE=$1
FILE=$2

mkdir -p /mnt/crypt
cryptsetup plainOpen --allow-discards -d ~/.ssh/dm-key.pub /dev/$BASE"2" dm-keys
mount /dev/mapper/dm-keys /mnt/crypt

mapfile -t < /mnt/crypt/.dm-keys/hash.keys DMKEYS
#mapfile -t < openssl rsautl -decrypt -inkey ~/.ssh/dm-key.pem < /mnt/crypt/.dm-keys/hash.keys

NUMPTS=$(grep -c $BASE[0-9] /proc/partitions)

mkdir -p /mnt/storage
echo "Found $NUMPTS partitions."
MAXNUMVOLS=128
i=3
#idx=1
while [ $i -lt $(($NUMPTS+1)) ]
do
    echo "Locating mapping for /dev/$BASE$i"
    UUID=$(echo blkid -s UUID -o value /dev/$BASE$i)
    #HASH="$(./Hash 32 $UUID)"
    #IDX=$(echo $HASH%$MAXTABLESIZE | bc)
    #echo ${DMKEYS[$(($i-2))]}
    #NOTE: not using hash here
    #(echo ${DMKEYS[$(($i-2))]}) | cryptsetup plainOpen --allow-discards -d - /dev/$BASE$i encpt$(($i-2))
    if [ -f /mnt/crypt/key$(($i-2)) ]
    then
        echo "Loading encpt$(($i-2))"
        cryptsetup plainOpen --allow-discards --key-file /mnt/crypt/key$(($i-2)) /dev/$BASE$i encpt$(($i-2))
    #else
    #    echo "Loading storage/pt$idx"
    #    mkdir -p /mnt/storage/pt$idx
    #    mount /dev/$BASE$i /mnt/storage/pt$idx -t ext4
    #    idx=$(($idx+1))
    fi
    i=$(($i+1))
done

mkdir -p /media/$USER/crypt

NUMVGS=$(vgs --all --noheadings | wc -l)
i=1
while [ $i -lt $(($NUMVGS+1)) ]
do
    echo "Restoring encrypted volume group $i"
    vgcfgrestore -f /mnt/crypt/encvg$i encvg$i
    vgchange -ay encvg$i
    if [ -e /dev/encvg$i/enclv$i ]
    then
        if [ $NUMVGS -gt 1 ]
        then
            mkdir -p /mnt/enclv$i
            mount /dev/encvg$i/enclv$i /mnt/enclv$i -t ext4
            e2label /dev/encvg$i/enclv$i crypt$i
        else
            mount /dev/encvg$i/enclv$i /media/$USER/crypt -t ext4
            e2label /dev/encvg$i/enclv$i crypt
        fi
        MNTS[$i]=/mnt/enclv$i
    fi
    i=$(($i+1))
done

if [ $NUMVGS -gt 1 ]
then
    echo mhddfs $(printf "%s\n" "${MNTS[@]}" | paste -sd,) /media/$USER/crypt
    mhddfs $(printf "%s\n" "${MNTS[@]}" | paste -sd,) /media/$USER/crypt
fi

#umount /mnt/crypt
#cryptsetup close dm-keys

chmod -R 0777 /media/$USER/crypt
rm "before.sum"
./checksum.sh $FILE $BASE

