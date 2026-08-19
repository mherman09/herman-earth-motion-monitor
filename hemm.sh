#!/bin/bash

SLEEP=200
if [ "$1" != "" ]
then
    SLEEP=$1
fi

# Globe animation (in development)
DO_ANIMATION=Y
ANIMATION_FREQUENCY=10


I_ANIMATION=0
CONTINUE=Y
while [ "$CONTINUE" == "Y" ]
do
    echo
    echo
    touch param.dat
    make all
    echo
    echo
    DO_ANIMATION=$(echo $I_ANIMATION $ANIMATION_FREQUENCY | awk '{if($1%$2==0){print "Y"}else{print "N"}}')
    if [ "$DO_ANIMATION" == "Y" ]
    then
        make animation
    fi
    I_ANIMATION=$(echo $I_ANIMATION $ANIMATION_FREQUENCY | awk '{print ($1+1)%$2}')
    echo
    echo
    echo sleeping for $SLEEP seconds
    sleep ${SLEEP}s
    echo
    echo
done