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



# Date/time print function
function print_time () {
    date "+%H:%M:%S"
}



# Set log file name
PWD=`pwd`
test -d LOGS || mkdir LOGS
LOG_FILE=${PWD}/LOGS/$SCRIPT.log


# Initialize log file
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


# Check that data window is defined
if [ "$WINDOW_SECONDS" == "" ]
then
    echo "$SCRIPT [ERROR]: WINDOW_SECONDS is blank" 1>&2
    exit 1
fi

# TODO: CHECK TO MAKE SURE WINDOW IS REASONABLE AMOUNT OF TIME (0-1 DAY?)

# All good, print window and proceed
echo "$SCRIPT [`print_time`]: getting $WINDOW_SECONDS seconds of data" | tee -a $LOG_FILE



# If starting time is specified in the param.dat file, use it, otherwise get records up to present
CALENDAR_TIME_START=`grep "^CALENDAR_TIME_START=" param.dat |\
    tail -1 |\
    awk -F"#" '{print $1}' |\
    sed -e "/^$/d" |\
    awk -F"=" '{print $2}' |\
    sed -e "/^$/d" |\
    awk '{print $1}'`



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

        # Check date is valid
        date -ju -f "%Y-%m-%dT%H:%M:%S" "$CALENDAR_TIME_START" "+%s" 1> /dev/null || { exit 1; }

        # Get end time
        EPOCH_TIME_END=`date -ju -f "%Y-%m-%dT%H:%M:%S" "$CALENDAR_TIME_START" "+%s" | awk '{print $1+'$WINDOW_SECONDS'}'`

    elif [ "$DATE_VERSION" == "gnu-date" ]
    then

        # Check date is valid
        date -u -d "$CALENDAR_TIME_START" "+%s" 1> /dev/null || { exit 1; }

        # Get end time
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
    CALENDAR_TIME_START=`date -u -r ${EPOCH_TIME_START} "+%Y-%m-%dT%H:%M:%S"`
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
rm *.mseed
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
echo "$SCRIPT [`print_time`]: downloading waveforms from NSF SAGE" | tee -a $LOG_FILE
echo "$SCRIPT [`print_time`]: saving query URLs in log file" | tee -a $LOG_FILE


for STA_INFO in `echo $STA_LIST | sed -e "s/,/ /g"`
do

    echo "$SCRIPT [`print_time`]: working on $STA_INFO" | tee -a $LOG_FILE


    # Parse station info
    STNM=`echo $STA_INFO | awk -F"|" '{print $1}'`
    NET=`echo $STA_INFO | awk -F"|" '{print $2}'`
    LOC=`echo $STA_INFO | awk -F"|" '{print $3}'`
    CHA=BHZ


    # Build SAGE query
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
    MSEED_FILE=./SAC/$NET.$STNM.$LOC.$CHA.mseed
    PZRESP_FILE=./SAC/PZRESP.$NET.$STNM.$LOC.$CHA
    curl "${FDSN_QUERY_STRING}" --output $MSEED_FILE 2>> $LOG_FILE
    curl "${SACPZ_QUERY_STRING}" --output $PZRESP_FILE 2>> $LOG_FILE


    # Error checks on MSEED download

    # Check that MSEED file exists
    ERROR_MESSAGE=$(test -f $MSEED_FILE || echo DOESNOTEXIST)
    if [ "$ERROR_MESSAGE" == "DOESNOTEXIST" ]
    then
        echo "$SCRIPT [WARNING]: MSEED file $MSEED_FILE was not downloaded" | tee -a $LOG_FILE
        echo "$SCRIPT [WARNING]: removing $MSEED_FILE and $PZRESP_FILE and continuing" | tee -a $LOG_FILE
        rm $MSEED_FILE $PZRESP_FILE
        continue
    fi

    # Check that MSEED file has size greater than zero
    ERROR_MESSAGE=$(test -s $MSEED_FILE || echo ZERO)
    if [ "$ERROR_MESSAGE" == "ZERO" ]
    then
        echo "$SCRIPT [WARNING]: downloaded MSEED file $MSEED_FILE has nothing in it" | tee -a $LOG_FILE
        echo "$SCRIPT [WARNING]: removing $MSEED_FILE and $PZRESP_FILE and continuing" | tee -a $LOG_FILE
        rm $MSEED_FILE $PZRESP_FILE
        continue
    fi

    # Check that MSEED download did not have another error
    ERROR_MESSAGE=$(test -f $MSEED_FILE && grep "Error" $MSEED_FILE)
    if [ "$ERROR_MESSAGE" != "" ]
    then
        echo "$SCRIPT [WARNING]: error in downloaded MSEED file $MSEED_FILE" | tee -a $LOG_FILE
        echo "$SCRIPT [WARNING]: see error message in $LOG_FILE" | tee -a $LOG_FILE
        cat $MSEED_FILE >> $LOG_FILE
        echo "$SCRIPT [WARNING]: removing $MSEED_FILE and $PZRESP_FILE and continuing" | tee -a $LOG_FILE
        rm $MSEED_FILE $PZRESP_FILE
        continue
    fi


    # Unzip miniseed file
    MSEED_FILE=$(basename $MSEED_FILE)
    PZRESP_FILE=$(basename $PZRESP_FILE)
    cd SAC
    test -f $MSEED_FILE && mseed2sac $MSEED_FILE >> $LOG_FILE 2>&1 || {
        echo "$SCRIPT [WARNING]: failed to unpack $MSEED_FILE" | tee -a $LOG_FILE ;
        echo "$SCRIPT [WARNING]: removing $MSEED_FILE and $PZRESP_FILE and continuing" | tee -a $LOG_FILE ;
        rm $MSEED_FILE $PZRESP_FILE ;
        cd .. ;
        continue ;
    }


    # Set STLO/STLA if they are not in the SAC header already
    STLO=`saclhdr -STLO *${STNM}*.SAC`
    if [ "$STLO" == "-12345" ]
    then
        echo "$SCRIPT [`print_time`]: station $STNM coordinates not in SAC header...extracting from PZRESP file" | tee -a $LOG_FILE
        STLO=$(grep "LONGITUDE" ../SAC/PZRESP*${STNM}* | sed -e "s/.*://" | awk '{print $1}')
        STLA=$(grep "LATITUDE" ../SAC/PZRESP*${STNM}* | sed -e "s/.*://" | awk '{print $1}')
        sac << --------EOF
        r *${STNM}*SAC
        ch STLO $STLO
        ch STLA $STLA
        wh
        q
--------EOF
    fi

    # Clean up SAC/ directory and return to HEMM directory
    cd ..
    echo >> $LOG_FILE

done



# Save downloaded files to log
echo >> $LOG_FILE
if [ -z "$(ls -A SAC/*.SAC 2> /dev/null)" ]
then
    echo "$SCRIPT [ERROR]: no downloaded seismograms found in SAC/" 1>&2
    exit 1
fi
echo "$SCRIPT [`print_time`]: SAC files" >> $LOG_FILE
ls ./SAC/*.SAC >> $LOG_FILE
echo >> $LOG_FILE
echo "$SCRIPT [`print_time`]: PZRESP files" >> $LOG_FILE
ls ./SAC/PZRESP* >> $LOG_FILE
echo >> $LOG_FILE



echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE
