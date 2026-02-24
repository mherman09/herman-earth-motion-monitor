#!/bin/bash

####################################################################################################
# RUN_CHECKS.SH
#
# Make sure required programs are in user's PATH for Herman Earth Motion Monitor
####################################################################################################


#####
#   INITIALIZE LOG FILE AND DETERMINE WHICH VERSION OF DATE TO USE
#####


# Script name
SCRIPT=`basename $0`



# Date/time function
function print_time () {
    date "+%H:%M:%S"
}



# Log file
PWD=`pwd`
test -d LOGS || mkdir LOGS
LOG_FILE=${PWD}/LOGS/$SCRIPT.log
echo "$SCRIPT [`print_time`]: starting" | tee $LOG_FILE
echo "$SCRIPT [`print_time`]: creating log file LOGS/$SCRIPT.log" | tee -a $LOG_FILE



# Determine date version
DATE_VERSION=$(date --version > /dev/null 2>&1 && echo "gnu-date" || echo "bsd-date")

if [ "$DATE_VERSION" == "bsd-date" ]
then
    echo "$SCRIPT [`print_time`]: using BSD date" | tee -a $LOG_FILE
elif [ "$DATE_VERSION" == "gnu-date" ]
then
    echo "$SCRIPT [`print_time`]: using GNU date" | tee -a $LOG_FILE
else
    echo "$SCRIPT [ERROR]: could not figure out version of date" 1>&2
    exit 1
fi






#####
#	CHECK FOR EXECUTABLES IN USER'S PATH
#####


for EXEC in curl \
            sac \
            gsac \
            saclhdr \
            gmt \
            lola2distaz
do
    echo "$SCRIPT [`print_time`]: looking for ${EXEC}" | tee -a $LOG_FILE
    which ${EXEC} > /dev/null || { echo "$0: could not find ${EXEC}: exiting" 1>&2 ; exit 1 ; }
    echo "$SCRIPT [`print_time`]: found `which ${EXEC}`" | tee -a $LOG_FILE
done


echo "$SCRIPT [`print_time`]: found all required executables - GOOD TO GO!" | tee -a $LOG_FILE

