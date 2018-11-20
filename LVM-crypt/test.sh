#!/bin/bash


#echo "OK"
#CURKEY=$(dd if=/dev/random bs=512 count=4)
#UUID="AString"
#HASH="$(./Hash 4 $UUID)"
#IDX=$(echo $HASH%50 | bc)
#echo $IDX
#DMKEYS[$IDX]=$CURKEY
#touch testFile
#echo "TESTING" >> testFile

#PTS=$(pvs --noheadings -o pv_name | sed 's/:.*//' )

#for x in $PTS
#do echo $x
#done

NUMFILES=50
while [ $NUMFILES -gt 1 ]
do
    echo "Testing $NUMFILES files"
    SIZEFILE=$((50 / $NUMFILES))
    echo $SIZEFILE"MB"
    j=1
    while [ $j -lt $NUMFILES ]
    do
        dd if=/dev/zero of=$SIZEFILE"MB-"$NUMFILE bs=$SIZEFILE"M" count=4096
        j=$(($j+1))
    done
    NUMFILES=$(($NUMFILES-1))
done

