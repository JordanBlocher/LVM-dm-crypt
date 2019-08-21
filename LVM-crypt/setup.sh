#!/bin/bash

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

USER=$(echo $SUDO_USER)

#printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
#read BASE
BASE=$1
#printf "Specify the filesystem: (i.e. exfat, ext4, ..)\n"
#read FILE
FILE=$2

FREE=$(parted /dev/$BASE print free | grep 'Free Space' | tail -n1 | awk '{print $3}')
printf "$FREE space detected, creating crypt partition.\n"
# Make home 
START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')

parted -a optimal /dev/$BASE mkpart primary 0% 61440MB
mkfs.exfat -n crypt /dev/$BASE"1"
mkdir -p /media/$USER/crypt
mount /dev/$BASE"1" /media/$USER/crypt
mkdir -p /mnt/crypt

# Make key storage
START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')
START=${START%"MB"}
END=$(echo 4+$START | bc)
parted -a optimal /dev/$BASE mkpart primary $START"MB" $END"MB"
parted /dev/$BASE set 2 hidden on

# Encrypt master key
#printf "Use GPG Key? (y/n)"
#read GEN
#if [ "$GEN" = "y" ];
#then
#    dd if=/dev/random bs=512 count=4 | gpg -symmetric > ~/.gnupg/dm-key.gpg
#fi 

if [ ! -f ~/.ssh/dm-key.pub.pem ]
then
    echo "CREATING ENCRYPTED KEY CONTAINER ..."
    ssh-keygen -f ~/.ssh/dm-key
    openssl rsa -in ~/.ssh/dm-key -pubout > ~/.ssh/dm-key.pub.pem
    openssl rsa < ~/.ssh/dm-key  > ~/.ssh/dm-key.pem
fi
cryptsetup plainOpen --allow-discards -d ~/.ssh/dm-key.pub /dev/$BASE"2" dm-keys

# Mount encrypted partition for keys
umount /mnt/crypt
mkfs.$FILE /dev/mapper/dm-keys
mount /dev/mapper/dm-keys /mnt/crypt
e2label /dev/mapper/dm-keys crypt
mkdir -p /mnt/crypt/.dm-keys
mkdir -p /mnt/crypt/.partmap

# Create the encrypted blocks
NUMBLOCKS=6
NUMVOLS=2
MAXTABLESIZE=128
FREE=$(parted /dev/$BASE unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}')
j=1
i=1
touch  /mnt/crypt/.partmap/uuids
while [ $j -lt $NUMVOLS ]
do
    echo "CREATING PARTITIONS FOR VOLUME GROUP $j"
    END=$(($j * $NUMBLOCKS))
    while [ $i -lt $END ]
    do
        START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')
        START=${START%"MB"}
        END=$(echo 12+$START | bc)
        parted -a optimal /dev/$BASE mkpart primary $START $END
        parted /dev/$BASE set $(($i+2)) LVM on
        echo "Creating /dev/$BASE$(($i+2))"
        #CURKEY=$(dd if=/dev/random bs=512 count=1)
        echo dd if=/dev/random bs=512 count=1 > /mnt/crypt/key$i
        echo "KEY$i"
        cat /mnt/crypt/key$i
        #(echo $CURKEY) | cryptsetup plainOpen --allow-discards -d - /dev/$BASE$(($i+2)) encpt$i
        cryptsetup plainOpen --allow-discards --key-file /mnt/crypt/key$i /dev/$BASE$(($i+2)) encpt$i
        echo "Mapping /dev/$BASE$(($i+2)) /dev/mapper/encpt$i"
        PTS=$PTS" /dev/mapper/encpt$i"
        UUID=$(echo blkid -s UUID -o value /dev/$BASE$((($i+2))))
        HASH="$(./Hash 32 $UUID)"
        IDX=$(echo $HASH%$MAXTABLESIZE | bc)
        #NOTE: not using hash here
        PTHASHES[$i]=$CURKEY
        i=$(($i+1))
        END=$(($j * $NUMBLOCKS))
        mount -a
    done
    pvcreate $PTS
    echo "CREATING ENCRYPTED VOLUME GROUP $j from $PTS"
    vgcreate encvg$j $PTS
    VUUID=$(vgs encvg$j -o vg_uuid --noheadings --nosuffix)
    PTS=""
    SIZE=$(vgs encvg$j -o vg_size --noheadings)
    echo "CREATING LV $j"
    lvcreate -l 100%FREE -nenclv$j encvg$j
    mkfs.$FILE /dev/mapper/encvg$j-enclv$j
    j=$(($j+1))
done

echo "STORING KEY TABLE..."
# Save hash table



echo ${DMKEYS[@]}
(echo printf "%s\n" "${DMKEYS[@]}") | openssl rsautl -encrypt -inkey ~/.ssh/dm-key.pem > /mnt/crypt/.dm-keys/hash.keys
printf "%s\n" "${DMKEYS[@]}" > /mnt/crypt/.dm-keys/hash.keys

j=1
i=1
while [ $j -lt $NUMVOLS ]
do
    vgcfgbackup -f /mnt/crypt/encvg$i
    END=$(($j * $NUMBLOCKS))
    while [ $i -lt $END ]
    do
        UUID=$(echo blkid -s UUID -o value /dev/$BASE$((($i+2))))
        echo $BASE$(($i+2)) " > " encpt$i >> /mnt/crypt/.partmap/uuids
        UUID=$(echo blkid -s UUID -o value /dev/mapper/encpt$i)
        echo $(blkid -s UUID -o value /dev/mapper/encpt$i) >> /mnt/crypt/.partmap/uuids
        #cryptsetup close encpt$i
        i=$(($i+1))
    done
    vgchange -an encvg$j
    j=$(($j+1))
done

umount /mnt/crypt
cryptsetup close dm-keys

j=1
i=$NUMBLOCKS
echo "CREATING PARTITIONS FOR STORAGE..."
while [ $j -lt $NUMVOLS ]
do
    END=$(($j * $((2*$NUMBLOCKS))))
    while [ $i -lt $END ]
    do
        START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')
        START=${START%"MB"}
        END=$(echo 12+$START | bc)
        parted -a optimal /dev/$BASE mkpart primary $START $END
        echo "Creating /dev/$BASE$(($i+2))"
        mkfs.$FILE /dev/$BASE$(($i+2))
        i=$(($i+1))
        END=$(($j * $((2*$NUMBLOCKS))))
        mount -a
    done
    j=$(($j+1))
done

echo "DONE..."
