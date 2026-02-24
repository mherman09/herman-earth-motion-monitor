#!/bin/bash


####################################################################################################
# PLOT_WAVEFORMS.SH
#
# Plot seismogram time series with significant earthquakes (minimum significance from param.dat)
####################################################################################################


# set -e


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



# Waveform download log file has time series start/end information
WVFM_LOG_FILE=${PWD}/LOGS/download_waveforms.sh.log
test -f $WVFM_LOG_FILE || { echo "$0 [ERROR]: could not find waveform log file $WVFM_LOG_FILE" 1>&2; exit 1; }








#####
#   PLOT PARAMETERS
#####


# Get screen dimensions
echo "$SCRIPT [`print_time`]: getting screen dimensions" | tee -a $LOG_FILE
SCREEN_DIMENSIONS=$(xrandr | awk '{if(/ connected/ && /primary/){print $(NF-2),$NF}}')
SCREEN_UNITS=$(echo $SCREEN_DIMENSIONS | awk '{print $1}' | sed -e "s/[0-9]*//")
SCREEN_X=$(echo $SCREEN_DIMENSIONS | sed -e "s/$SCREEN_UNITS//g" | awk '{print $1}')
SCREEN_Y=$(echo $SCREEN_DIMENSIONS | sed -e "s/$SCREEN_UNITS//g" | awk '{print $2}')
echo SCREEN_UNITS=$SCREEN_UNITS
echo SCREEN_X=$SCREEN_X
echo SCREEN_Y=$SCREEN_Y



# Convert dimensions to inches
echo "$SCRIPT [`print_time`]: converting screen dimensions to inches" | tee -a $LOG_FILE

if [ "$SCREEN_UNITS" == "mm" ]
then
    SCREEN_X=$(echo $SCREEN_X | awk '{print $1/25.4}')
    SCREEN_Y=$(echo $SCREEN_Y | awk '{print $1/25.4}')
else
    echo "$SCRIPT [ERROR]: unknown screen dimension unit $SCREEN_UNITS" 1>&2
    echo "Tell Matt to fix this" 1>&2
    exit 1
fi
echo SCREEN_X=$SCREEN_X
echo SCREEN_Y=$SCREEN_Y



# Set paper size to be screen dimensions
echo "$SCRIPT [`print_time`]: setting PS_MEDIA to ${SCREEN_X}ix${SCREEN_Y}i" | tee -a $LOG_FILE
gmt set PS_MEDIA ${SCREEN_X}ix${SCREEN_Y}i



# Postscript file name
PSFILE=waveforms.ps



# Plot dimensions
WHITESPACE_X=0.25
WHITESPACE_Y=0.25
X_AXIS_HGT=0.7
TOTAL_WID=$(echo $SCREEN_X | awk '{print $1-'$WHITESPACE_X'*2}')      # Total plot width (in)
TOTAL_HGT=$(echo $SCREEN_Y | awk '{print $1-'$WHITESPACE_Y'*2}')      # Total plot height (in)
echo "$SCRIPT [`print_time`]: setting plot width to ${TOTAL_WID} in" | tee -a $LOG_FILE
echo "$SCRIPT [`print_time`]: setting plot height to ${TOTAL_HGT} in" | tee -a $LOG_FILE










#####
#   PLOT TIME SERIES
#####



# Number of seismograms to plot
N=`ls SAC/*.sac | wc | awk '{print $1}'`                                        # Number of seismograms to plot
echo "$SCRIPT [`print_time`]: plotting $N seismograms" | tee -a $LOG_FILE



# Seismogram dimensions
TRACE_WID=$TOTAL_WID                                                            # Width of each seismogram (in)
TRACE_SHFT_HGT=`echo $TOTAL_HGT $X_AXIS_HGT $N | awk '{print ($1-$2)/$3}'`      # Vertical spacing between each seismogram (in)
TRACE_RATIO=1.00                                                                # Relative height of each seismogram
TRACE_HGT=`echo $TRACE_SHFT_HGT $TRACE_RATIO | awk '{print $1*$2}'`             # Height of each seismogram (in)
echo "$SCRIPT [`print_time`]: setting each trace width to ${TRACE_WID} in" | tee -a $LOG_FILE
echo "$SCRIPT [`print_time`]: setting each trace height to ${TRACE_HGT} in" | tee -a $LOG_FILE



# Vertical spacing between each seismogram
SHFT=$TRACE_SHFT_HGT
echo "$SCRIPT [`print_time`]: setting vertical shift between traces to ${SHFT} in" | tee -a $LOG_FILE



# Cartesian axes
PROJ=-JX${TRACE_WID}i/${TRACE_HGT}i
echo "$SCRIPT [`print_time`]: PROJ=$PROJ" | tee -a $LOG_FILE



# Initialize figure
echo "$SCRIPT [`print_time`]: initializing figure" | tee -a $LOG_FILE
SHFT_Y=$(echo $TOTAL_HGT $X_AXIS_HGT | awk '{print $1-$2}')
gmt psxy -T -K -X${WHITESPACE_X}i -Y${SHFT_Y}i -P > $PSFILE



# Get times of requested window from waveform download log file
echo "$SCRIPT [`print_time`]: getting seismogram timing from LOGS/download_waveforms.sh.log" | tee -a $LOG_FILE
WINDOW_SECONDS=`grep "WINDOW_SECONDS" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
WINDOW_MINUTES=`echo $WINDOW_SECONDS | awk '{print $1/60}'`
EPOCH_TIME_START=`grep "EPOCH_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START_LOCAL=`grep "CALENDAR_TIME_START_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END_LOCAL=`grep "CALENDAR_TIME_END_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
TIME_ZONE_LOCAL=`grep "TIME_ZONE_LOCAL=" $WVFM_LOG_FILE | awk -F= '{print $2}'`
cat > j << EOF
WINDOW_SECONDS=$WINDOW_SECONDS
WINDOW_MINUTES=$WINDOW_MINUTES
CALENDAR_TIME_START=$CALENDAR_TIME_START
CALENDAR_TIME_END=$CALENDAR_TIME_END
CALENDAR_TIME_START_LOCAL=$CALENDAR_TIME_START_LOCAL
CALENDAR_TIME_END_LOCAL=$CALENDAR_TIME_END_LOCAL
TIME_ZONE_LOCAL=$TIME_ZONE_LOCAL
EOF
cat j | tee -a $LOG_FILE
rm j



# Plot all waveforms, starting with California stations
for TRACE in SAC/*.CI.*.sac SAC/*.IU.*.sac
do

    echo "$SCRIPT [`print_time`]: plotting trace $TRACE" | tee -a $LOG_FILE


    # Get directory name and ASCII seismogram file name
    DIR=`dirname $TRACE`
    ASCII_FILE=`basename $TRACE .sac`.dat


    # Get min/max velocities to scale trace
    DEPMIN=`saclhdr -DEPMIN $TRACE`
    DEPMAX=`saclhdr -DEPMAX $TRACE`
    LIMS=-R0/3600/${DEPMIN}/${DEPMAX}


    # Get start time of trace
    NZYEAR=`saclhdr -NZYEAR $TRACE`
    NZJDAY=`saclhdr -NZJDAY $TRACE | awk '{print $1+0}'`
    NZHOUR=`saclhdr -NZHOUR $TRACE`
    NZMIN=`saclhdr -NZMIN $TRACE`
    NZSEC=`saclhdr -NZSEC $TRACE`
    if [ "$DATE_VERSION" == "bsd-date" ]
    then
        NZDATE="${NZYEAR}-${NZJDAY}T${NZHOUR}:${NZMIN}:${NZSEC}"
        EPOCH_TIME_TRACE_START=`date -ju -f "%Y-%jT%H:%M:%S" "$NZDATE" "+%s"`
    elif [ "$DATE_VERSION" == "gnu-date" ]
    then
        DAYOFYEAR=`echo $NZJDAY | awk '{print $1-1}'`
        EPOCH_TIME_TRACE_START=`date -u -d "Jan 1, $NZYEAR + $DAYOFYEAR days + $NZHOUR hours + $NZMIN minutes + $NZSEC seconds" "+%s"`
    else
        echo Could not figure out which date version to use...exiting 1>&2
        exit 1
    fi


    # Calculate time shift
    DT=`echo $EPOCH_TIME_START $EPOCH_TIME_TRACE_START | awk '{print $2-$1}'`


    # Plot waveform
    awk 'BEGIN{dt='$DT'}{
        if (NR==1) {
            delta = $1
        } else if (NR>30) {
            for(i=1;i<=NF;i++){
                t = ((NR-31)*5+i)*delta + dt
                v = $i
                printf("%12.3f%20.6e\n"), t,v
            }
        }
    }' $DIR/$ASCII_FILE |\
        gmt psxy $PROJ $LIMS -W0.5p,65 -K -O --PS_LINE_JOIN=round >> $PSFILE

    # Plot station name
    KSTNM=`saclhdr -KSTNM $TRACE`
    DESCRIPTION=`grep DESCRIPTION SAC/PZRESP*.$KSTNM.* | awk -F":" '{print $2}'`
    echo "$DESCRIPTION ($KSTNM)" | gmt pstext $PROJ $LIMS -F+f12,3+cTR -D-0.05i/0 -K -O >> $PSFILE


    # Plot frame (usually leave commented)
    # gmt psbasemap $PROJ $LIMS -Bxf -Byf -K -O >> $PSFILE


    # Shift down to plot next waveform
    gmt psxy -T -K -O -Y-${SHFT}i >> $PSFILE

done









#####
#   PLOT SIGNIFICANT EARTHQUAKES
#####


# Shift origin back up one waveform
gmt psxy -T -K -O -Y${SHFT}i >> $PSFILE



# New frame parameters for significant earthquake bars
echo "$SCRIPT [`print_time`]: setting new frame parameters for significant earthquakes" | tee -a $LOG_FILE
HGT=`echo $N $TRACE_HGT $SHFT | awk '{print ($1-1)*$3+$2}'`
PROJ=-JX${TOTAL_WID}i/${HGT}i
LIMS=-R0/$WINDOW_MINUTES/0/1
echo PROJ=$PROJ | tee -a $LOG_FILE
echo LIMS=$LIMS | tee -a $LOG_FILE



# Download significant earthquakes
echo "$SCRIPT [`print_time`]: downloading significant earthquakes" | tee -a $LOG_FILE
MINSIG=$(grep "^MINSIG=" param.dat | tail -1 | awk -F= '{print $2}')
if [ -z $MINSIG ]
then
    MINSIG=100
fi
echo "$SCRIPT [`print_time`]: minimum significance = $MINSIG" | tee -a $LOG_FILE
COMCAT_URL="https://earthquake.usgs.gov/fdsnws/event/1/query?starttime=${CALENDAR_TIME_START}&endtime=${CALENDAR_TIME_END}&minsig=${MINSIG}&format=csv"
echo "$COMCAT_URL" >> $LOG_FILE
curl "$COMCAT_URL" > query.csv 2>> $LOG_FILE



# Check for server errors...
USGS_EQ_QUERY_ERROR=`grep "Internal Server Error" query.csv || echo`
if [ "$USGS_EQ_QUERY_ERROR" != "" ]
then
    USGS_EQ_QUERY_ERROR="Y"
else
    USGS_EQ_QUERY_ERROR="N"
fi



# If no server error, extract events and plot timing on waveforms
if [ "$USGS_EQ_QUERY_ERROR" == "N" ]
then

    NSIG=$(wc query.csv | awk '{print $1}')
    echo "$SCRIPT [`print_time`]: plotting $NSIG significant earthquakes" | tee -a $LOG_FILE


    # Reverse order of events
    awk '{line[NR]=$0}END{for(i=NR;i>1;i--){print line[i]}}' query.csv > j
    mv j query.csv


    # Save significant earthquakes
    echo "$SCRIPT [`print_time`]: saving significant earthquakes in sig_eq.tmp" | tee -a $LOG_FILE
    awk -F, '{print $1,$2,$3,$4,$5}' query.csv > sig_eq.tmp
    awk '{print $5}' sig_eq.tmp > mag.tmp



    # Calculate number of seconds from start time to earthquake
    echo "$SCRIPT [`print_time`]: calculating significant earthquake timing" | tee -a $LOG_FILE
    if [ "$DATE_VERSION" == "bsd-date" ]
    then
        awk -F"." '{print $1}' sig_eq.tmp | xargs date -ju -f "%Y-%m-%dT%H:%M:%S" "+%s" |\
            awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
    elif [ "$DATE_VERSION" == "gnu-date" ]
    then
        awk -F"." '{print $1}' sig_eq.tmp | xargs -I ^ date -u -d ^ "+%s" |\
            awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
    else
        echo Could not figure out which date version to use...exiting 1>&2
        exit 1
    fi


    # Plot significant earthquakes
    echo "$SCRIPT [`print_time`]: plotting significant earthquakes" | tee -a $LOG_FILE
    paste time.tmp mag.tmp |\
        awk '{
            t = $1/60

            if ($2>=8) {PEN=3+($2-8);print "> -W"PEN"p,red@15";print t,0;print t,1}
            else if ($2>=7) {PEN=2+($2-7);print "> -W"PEN"p,red@30";print t,0;print t,1}
            else if ($2>=6) {PEN=1+($2-6);print "> -W"PEN"p,red@40";print t,0;print t,1}
            else if ($2>=5.5) {print "> -W1p,orange@40";print t,0;print t,1}
            else if ($2>=5.0) {print "> -W1p,palegreen3@40";print t,0;print t,1}
            else {print "> -W1p,lightsteelblue3@40";print t,0;print t,1}
        }' |\
        gmt psxy $PROJ $LIMS -K -O >> $PSFILE


    # Remove temporary files
    rm mag.tmp time.tmp

fi








#####
#   FINALIZE PLOT & CLEAN UP
#####


# Label and annotate x-axis (time)
echo "$SCRIPT [`print_time`]: generating time axis" | tee -a $LOG_FILE
LIMS=-R-$WINDOW_MINUTES/0/0/1
gmt psbasemap $PROJ $LIMS -Bxa5+l"Time (Minutes)" -BS -K -O \
    --FONT_LABEL=20p \
    --FONT_ANNOT_PRIMARY=14p >> $PSFILE


# Label starting and ending times
echo "$SCRIPT [`print_time`]: labeling start and end times" | tee -a $LOG_FILE
echo $CALENDAR_TIME_START_LOCAL $TIME_ZONE_LOCAL |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f11,2+cBL -D0/-0.55i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_END_LOCAL $TIME_ZONE_LOCAL |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f11,2+cBR -D0/-0.55i -N -K -O >> $PSFILE



# # Full frame around image (usually leave commented out)
# echo "$SCRIPT [`print_time`]: plotting full frame around image" | tee -a $LOG_FILE
# gmt psxy -T -Y-${X_AXIS_HGT}i -K -O >> $PSFILE
# gmt psbasemap -JX${TOTAL_WID}i/${TOTAL_HGT}i $LIMS -Bf -K -O >> $PSFILE



# Finalize PostScript
gmt psxy -T -O >> $PSFILE



# Convert PostScript
echo "$SCRIPT [`print_time`]: converting PostScript to PNG" | tee -a $LOG_FILE
gmt psconvert $PSFILE -Tg -E300 -Qg4

# gmt psconvert $PSFILE -Tj -E720
# gmt psconvert $PSFILE -Tf


# Clean up
rm $PSFILE
rm gmt.history gmt.conf




echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE
