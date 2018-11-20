#!/bin/bash

set -e

ROOTUID="0"
if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    printf "This script must be executed with root privileges.\n"
exit 1
fi

USER=$(echo $SUDO_USER)

printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
read BASE

FREE=$(parted /dev/$BASE print free | grep 'Free Space' | tail -n1 | awk '{print $3}')
printf "$FREE space detected, creating Home partition.\n"
# Make home 
START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')

parted -a optimal /dev/$BASE mkpart primary 0% 61440MB
mkfs.exfat -n Home /dev/$BASE"1"
mkdir -p /media/$USER/Home
mount /dev/$BASE"1" /media/$USER/Home
mkdir -p /media/crypt

# Make key storage
START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')
START=${START%"MB"}
END=$(echo 512+$START | bc)
parted -a optimal /dev/$BASE mkpart primary $START"MB" $END"MB"
parted /dev/$BASE set 2 hidden on

# Encrypt master key
#printf "Use GPG Key? (y/n)"
#read GEN
#if [ "$GEN" = "y" ];
#then
#    dd if=/dev/random bs=512 count=4 | gpg -symmetric > ~/.gnupg/dm-key.gpg
#fi 

echo "CREATING ENCRYPTED KEY CONTAINER ..."
ssh-keygen -f ~/.ssh/dm-key
openssl rsa -in ~/.ssh/dm-key -pubout > ~/.ssh/dm-key.pub.pem
openssl rsa < ~/.ssh/dm-key  > ~/.ssh/dm-key.pem
cryptsetup luksFormat -v -y /dev/$BASE"2" 
cryptsetup luksOpen -v --allow-discards /dev/$BASE"2" dm-keys

# Mount encrypted partition for keys
mkfs.ext4 /dev/mapper/dm-keys
e2label /dev/mapper/dm-keys crypt
mount /dev/mapper/dm-keys /media/crypt

# Create the encrypted blocks
NUMBLOCKS=26
NUMVOLS=6
MAXTABLESIZE=128
FREE=$(parted /dev/$BASE unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}')
j=1
i=1
while [ $j -lt $NUMVOLS ]
do
    echo "CREATING PARTITIONS FOR VOLUME GROUP " $j
    END=$(($j * $NUMBLOCKS))
    while [ $i -lt $END ]
    do
        START=$(parted /dev/$BASE unit MB print free | grep 'Free' | tail -n1 | awk '{print $1}')
        START=${START%"MB"}
        END=$(echo 4+$START | bc)
        parted -a optimal /dev/$BASE mkpart primary $START $END
        parted /dev/$BASE set $(($i+2)) LVM on
        echo "Creating /dev/$BASE$(($i+2))"
        CURKEY=$(dd if=/dev/random bs=512 count=4)
        (echo $CURKEY) | cryptsetup luksFormat -v -d - /dev/$BASE$(($i+2))
        (echo $CURKEY) | cryptsetup luksOpen -v --allow-discards -d - /dev/$BASE$(($i+2)) encpt$i
        echo "Mapping /dev/$BASE$(($i+2)) /dev/mapper/encpt$i"
        PTS=$PTS" /dev/mapper/encpt$i"
        UUID=$(echo blkid -s UUID -o value /dev/$BASE$((($i+2))))
        echo $UUID
        HASH="$(./Hash 32 $UUID)"
        PTHASHES[i]=HASH
        i=$(($i+1))
        END=$(($j * $NUMBLOCKS))
        mount -a
    done
    pvcreate $PTS
    echo "CREATING ENCRYPTED VOLUME GROUP "$j " from " $PTS
    vgcreate encvg$j $PTS
    VUUID=$(vgs encvg$j -o vg_uuid --noheadings --nosuffix)
    PTS=""
    k=1
    while [ $k -lt $NUMBLOCKS ]
    do
        HASH="$(./AddHashes 32 $VUUID $PTHASHES[k] $)"
        IDX=$(echo $HASH%$MAXTABLESIZE | bc)
        DMKEYS[$(($IDX))]=$CURKEY
        k=$(($k+1))
    done
    SIZE=$(vgs encvg$j -o vg_size --noheadings)
    lvcreate -l 100%FREE -nenclv$j encvg$j
    mkfs.ext4 /dev/encvg$j/enclv$j
    mkdir -p /mnt/enclv$j
    mount /dev/encvg$j/enclv$j /mnt/enclv$j
    MNTS=$MNTS" /mnt/enclv$j"
    j=$(($j+1))
done


# Save hash table
mkdir -p /media/crypt/.dm-keys
echo ${DMKEYS[@]}
(echo printf "%s\n" "${DMKEYS[@]}") | openssl rsautl -encrypt -inkey ~/.ssh/dm-key.pem > /media/crypt/.dm-keys/hash.keys
umount /media/crypt
cryptsetup close /dev/mapper/dm-keys

mhddfs $MTS /media/crypt


