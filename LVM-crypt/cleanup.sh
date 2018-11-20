#!/bin/bash

printf "Specify the partition: (i.e. sdd, sdc, ..)\n"
read BASE

umount /media/frags/Home
umount /dev/mapper/dm-keys
cryptsetup close dm-keys
parted /dev/$BASE rm 2
parted /dev/$BASE rm 1

mount -a
