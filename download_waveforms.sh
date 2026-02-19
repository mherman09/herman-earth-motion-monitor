#!/bin/bash

####################################################################################################
# DOWNLOAD_WAVEFORMS.SH
#
# Download seismograms from IRIS using the date and window parameters in file param.dat
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
#	GET START AND END TIMES FOR WAVEFORMS FROM PARAM.DAT
#####


# Getting info from param.dat
echo "$SCRIPT [`print_time`]: getting waveform timing from param.dat" | tee -a $LOG_FILE



# Length of record in seconds specified in param.dat file
WINDOW_SECONDS=`grep "^WINDOW_SECONDS=" param.dat | tail -1 | awk -F"=" '{print $2}'`
echo "$SCRIPT [`print_time`]: getting $WINDOW_SECONDS seconds of data" | tee -a $LOG_FILE



# If starting time is specified in the param.dat file, use it, otherwise get records up to present
CALENDAR_TIME_START=`grep "^CALENDAR_TIME_START=" param.dat |\
    tail -1 |\
    awk -F"#" '{print $1}' |\
    sed -e "/^$/d" |\
    awk -F"=" '{print $2}' |\
    sed -e "/^$/d"`



# End time is either calculated relative to time set in param.dat or the current time
if [ "$CALENDAR_TIME_START" == "" ]
then
    echo "$SCRIPT [`print_time`]: CALENDAR_TIME_START not specified in param.dat" | tee -a $LOG_FILE
    echo "$SCRIPT [`print_time`]: getting time series up to present" | tee -a $LOG_FILE
    EPOCH_TIME_END=`date "+%s"`
else
    echo "$SCRIPT [`print_time`]: getting time series starting at UTC $CALENDAR_TIME_START" | tee -a $LOG_FILE
    if [ "$DATE_VERSION" == "bsd-date" ]
    then
        EPOCH_TIME_END=`date -ju -f "%Y-%m-%dT%H:%M:%S" "$CALENDAR_TIME_START" "+%s" | awk '{print $1+'$WINDOW_SECONDS'}'`
    elif [ "$DATE_VERSION" == "gnu-date" ]
    then
        EPOCH_TIME_END=`date -u -d "$CALENDAR_TIME_START" "+%s" | awk '{print $1+'$WINDOW_SECONDS'}'`
    else
        echo "$SCRIPT [ERROR]: could not figure out version of date" 1>&2
        exit 1
    fi
fi



# Start time
EPOCH_TIME_START=`echo $EPOCH_TIME_END $WINDOW_SECONDS | awk '{print $1-$2}'`



# Convert to calendar date in UTC for requesting download
if [ "$DATE_VERSION" == "bsd-date" ]
then
    CALENDAR_TIME_END=`date -u -r ${EPOCH_TIME_END} "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_PrepSTART=`date -u -r ${EPOCH_TIME_START} "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_END_LOCAL=`date -r "${EPOCH_TIME_END}" "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_START_LOCAL=`date -r "${EPOCH_TIME_START}" "+%Y-%m-%dT%H:%M:%S"`
elif [ "$DATE_VERSION" == "gnu-date" ]
then
    CALENDAR_TIME_END=`date -u -d "@${EPOCH_TIME_END}" "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_START=`date -u -d "@${EPOCH_TIME_START}" "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_END_LOCAL=`date -d "@${EPOCH_TIME_END}" "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_START_LOCAL=`date -d "@${EPOCH_TIME_START}" "+%Y-%m-%dT%H:%M:%S"`
else
    echo "$SCRIPT [ERROR]: could not figure out version of date" 1>&2
    exit 1
fi



# Save parameters in a log file
cat > j << EOF
WINDOW_SECONDS=$WINDOW_SECONDS
EPOCH_TIME_START=$EPOCH_TIME_START
EPOCH_TIME_END=$EPOCH_TIME_END
CALENDAR_TIME_START=$CALENDAR_TIME_START
CALENDAR_TIME_END=$CALENDAR_TIME_END
CALENDAR_TIME_START_LOCAL=$CALENDAR_TIME_START_LOCAL
CALENDAR_TIME_END_LOCAL=$CALENDAR_TIME_END_LOCAL
TIME_ZONE_LOCAL=`date "+%Z"`
EOF
cat j | tee -a $LOG_FILE
rm j






#####
#	DOWNLOAD WAVEFORMS AND STATION METADATA
#####


# Start download
echo "$SCRIPT [`print_time`]: preparing waveform download" | tee -a $LOG_FILE



# Make directory to store waveforms and clean it out
echo "$SCRIPT [`print_time`]: cleaning SAC/ directory" | tee -a $LOG_FILE
test -d SAC || mkdir SAC
cd SAC
rm *.SAC
rm PZRESP.*
rm *.dat
rm *.sac
rm sac.zip
cd ..



# List of seismic stations from param.dat file
echo "$SCRIPT [`print_time`]: getting list of stations from param.dat" | tee -a $LOG_FILE

STA_LIST=`awk -F"#" '{print $1}' param.dat |\
    awk '{
        if (/\*station_start\*/) {
            getline
            sta_list = $0
            getline
            while (!/\*station_end\*/) {
                sta_list = sprintf("%s,%s",sta_list,$0)
                getline
            }
        }
    } END{print sta_list}'`

echo $STA_LIST | tee -a $LOG_FILE



# Download waveforms and station instrument responses into SAC folder
echo "$SCRIPT [`print_time`]: downloading waveforms from IRIS" | tee -a $LOG_FILE
echo "$SCRIPT [`print_time`]: saving query URLs in log file" | tee -a $LOG_FILE


for STA_INFO in `echo $STA_LIST | sed -e "s/,/ /g"`
do

    echo "$SCRIPT [`print_time`]: working on $STA_INFO" | tee -a $LOG_FILE

    # Parse station info
    STNM=`echo $STA_INFO | awk -F"|" '{print $1}'`
    NET=`echo $STA_INFO | awk -F"|" '{print $2}'`
    LOC=`echo $STA_INFO | awk -F"|" '{print $3}'`
    CHA=BHZ

    # Build query
    QUERY_STRING="query?net=$NET"
    QUERY_STRING="${QUERY_STRING}&sta=$STNM"
    QUERY_STRING="${QUERY_STRING}&loc=$LOC"
    QUERY_STRING="${QUERY_STRING}&cha=$CHA"
    QUERY_STRING="${QUERY_STRING}&start=$CALENDAR_TIME_START"
    QUERY_STRING="${QUERY_STRING}&end=$CALENDAR_TIME_END"
    SACPZ_QUERY_STRING="https://service.earthscope.org/irisws/sacpz/1/${QUERY_STRING}"
    FDSN_QUERY_STRING="https://service.earthscope.org/fdsnws/dataselect/1/${QUERY_STRING}&format=miniseed"
    echo $SACPZ_QUERY_STRING >> $LOG_FILE
    echo $FDSN_QUERY_STRING >> $LOG_FILE


    # Download from NSF SAGE
    curl "${SACPZ_QUERY_STRING}" --output ./SAC/PZRESP.$NET.$STNM.$LOC.$CHA 2>> $LOG_FILE
    curl "${FDSN_QUERY_STRING}" --output ./SAC/file.mseed 2>> $LOG_FILE


    # Unzip miniseed file
    cd SAC
    test -f file.mseed  && mseed2sac file.mseed >> $LOG_FILE 2>&1 || echo failed to download/unzip $STNM file
    test -f file.mseed && rm file.mseed
    cd ..
    echo >> $LOG_FILE

done



# Save downloaded files to log
if [ -z "$(ls -A SAC/*.SAC 2> /dev/null)" ]
then
    echo "$SCRIPT [ERROR]: no downloaded seismograms found in SAC/" 1>&2
    exit 1
fi
ls ./SAC/PZRESP* >> $LOG_FILE
ls ./SAC/*.SAC >> $LOG_FILE



echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE
