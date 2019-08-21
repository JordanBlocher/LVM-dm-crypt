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

umount /mnt/crypt
umount /media/$USER/crypt
umount -a
cryptsetup close dm-keys

NUMVGS=$(vgs --all --noheadings | wc -l)
echo "Found $NUMVGS encrypted volumes."
i=1
while [ $i -lt $(($NUMVGS+1)) ]
do
    vgchange -an encvg$i
    if [ $NUMVGS -gt 1 ]
    then
        umount /mnt/enclv$i
        rm -r /mnt/enclv$i
    fi
    i=$(($i+1))
done

rm "after.sum"
./checksum.sh $FILE $BASE

NUMPTS=$(pvs --noheadings | wc -l)
PTS=$(pvs --noheadings -o pv_name | sed 's/:.*//')
echo "Found $NUMPTS encrypted partitions."
for PT in $PTS
do
    PTNAME=${PT##*/}
    echo "Closing $PTNAME"
    cryptsetup close $PTNAME
done

#./rsync_backup.sh

#umount /mnt/storage/*
#rm -r /mnt/storage
rm -r /mnt/crypt/*
rm -r /mnt/crypt
rm -r /media/$USER/crypt
