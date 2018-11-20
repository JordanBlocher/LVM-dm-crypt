#!/bin/bash


NUMFILES=50
rm diff.sum
rm count.sum
while [ $NUMFILES -gt 1 ]
do
    SIZEFILE=$((50 / $NUMFILES))
    #echo ${NUMFILES}-${SIZEFILE}M >> count.sum
    diff "/home/$USER/workload/${NUMFILES}-${SIZEFILE}M_before.sum" "/home/$USER/workload/${NUMFILES}-${SIZEFILE}M_after.sum" > ${NUMFILES}-${SIZEFILE}M.sum
    diff=$(cat ${NUMFILES}-${SIZEFILE}M.sum | wc -l )
    echo $NUMFILES $SIZEFILE $((($diff-4) / 2)) >> count.sum
    NUMFILES=$(($NUMFILES-1))
done

