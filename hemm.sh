#!/bin/bash

SLEEP=200
if [ "$1" != "" ]
then
    SLEEP=$1
fi


CONTINUE=Y
while [ "$CONTINUE" == "Y" ]
do
    echo
    echo
    touch param.dat
    make all
    echo
    echo
    echo sleeping for $SLEEP seconds
    sleep ${SLEEP}s
    echo
    echo
done