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
    ./do_all.sh || { echo $0: exiting with error; exit 1; }
    sleep $SLEEP
    echo
done