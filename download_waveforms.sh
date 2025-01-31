#!/bin/bash


#####
#   INITIALIZE LOG FILE
#####
LOG_FILE=$0.log
date "+%Y-%m-%dT%H:%M:%S" > $LOG_FILE
echo starting $0 >> $LOG_FILE




#####
#	GET START AND END TIMES FOR WAVEFORMS
#####

# Note: "date" options are apparently not portable - BSD and GNU date have different syntaxes :-(
# These scripts were developed on an iMac using the built-in date (BSD)


# Length of record in seconds specified in param.dat file
WINDOW_SECONDS=`grep "WINDOW_SECONDS" param.dat | awk -F"=" '{print $2}'`


# If starting time is specified in the param.dat file, use it, otherwise get records up to present
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" param.dat |\
    awk -F"#" '{print $1}' |\
    sed -e "/^$/d" |\
    awk -F"=" '{print $2}' |\
    sed -e "/^$/d"`


# End time is either calculated relative to time set in param.dat or the current time
if [ "$CALENDAR_TIME_START" == "" ]
then
    EPOCH_TIME_END=`date "+%s"`
else
    EPOCH_TIME_END=`date -ju -f "%Y-%m-%dT%H:%M:%S" "$CALENDAR_TIME_START" "+%s" | awk '{print $1+'$WINDOW_SECONDS'}'`
fi


# Start time
EPOCH_TIME_START=`echo $EPOCH_TIME_END $WINDOW_SECONDS | awk '{print $1-$2}'`


# Convert to calendar date in UTC for requesting download
CALENDAR_TIME_END=`date -u -r ${EPOCH_TIME_END} "+%Y-%m-%dT%H:%M:%S"`
CALENDAR_TIME_START=`date -u -r ${EPOCH_TIME_START} "+%Y-%m-%dT%H:%M:%S"`


# Save parameters in a log file
echo WINDOW_SECONDS=$WINDOW_SECONDS >> $LOG_FILE
echo EPOCH_TIME_START=$EPOCH_TIME_START >> $LOG_FILE
echo EPOCH_TIME_END=$EPOCH_TIME_END >> $LOG_FILE
echo CALENDAR_TIME_START=$CALENDAR_TIME_START >> $LOG_FILE
echo CALENDAR_TIME_END=$CALENDAR_TIME_END >> $LOG_FILE



#####
#	DOWNLOAD WAVEFORMS AND STATION METADATA
#####
# Make directory to store waveforms and clean it out
test -d SAC || mkdir SAC
cd SAC
rm *.SAC
rm PZRESP.*
rm *.dat
rm *.sac
rm sac.zip
cd ..


# List of seismic stations from param.dat file
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
echo $STA_LIST >> $LOG_FILE


# Download waveforms and station instrument responses into SAC folder
for STA_INFO in `echo $STA_LIST | sed -e "s/,/ /g"`
do
    # Build query string
    STNM=`echo $STA_INFO | awk -F"|" '{print $1}'`
    NET=`echo $STA_INFO | awk -F"|" '{print $2}'`
    LOC=`echo $STA_INFO | awk -F"|" '{print $3}'`
    echo $STNM $NET $LOC
    CHA=BHZ
    QUERY_STRING="query?net=$NET"
    QUERY_STRING="${QUERY_STRING}&sta=$STNM"
    QUERY_STRING="${QUERY_STRING}&loc=$LOC"
    QUERY_STRING="${QUERY_STRING}&cha=$CHA"
    QUERY_STRING="${QUERY_STRING}&start=$CALENDAR_TIME_START"
    QUERY_STRING="${QUERY_STRING}&end=$CALENDAR_TIME_END"
    SACPZ_QUERY_STRING="https://service.iris.edu/irisws/sacpz/1/${QUERY_STRING}"
    FDSN_QUERY_STRING="https://service.iris.edu/fdsnws/dataselect/1/${QUERY_STRING}&format=sac.zip"
    echo $SACPZ_QUERY_STRING >> $LOG_FILE
    echo $FDSN_QUERY_STRING >> $LOG_FILE

    # Download from IRIS
    curl "${SACPZ_QUERY_STRING}" > ./SAC/PZRESP.$NET.$STNM.$LOC.$CHA
    curl "${FDSN_QUERY_STRING}" > ./SAC/sac.zip

    # Unzip SAC file
    cd SAC
    test -f sac.zip && unzip sac.zip
    cd ..
done


# Save downloaded files to log
ls ./SAC/PZRESP* >> $LOG_FILE
ls ./SAC/*.SAC >> $LOG_FILE


echo finished $0 >> $LOG_FILE
