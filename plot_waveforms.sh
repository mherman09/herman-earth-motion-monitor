#!/bin/bash


####################################################################################################
# PLOT_WAVEFORMS.SH
#
# Plot seismogram time series with significant earthquakes (minimum significance from param.dat)
####################################################################################################


# set -e


#####
#   INITIALIZE LOG FILE AND DETERMINE DATE VERSION
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
echo "$SCRIPT [`print_time`]: progress and error messages saved in log file: LOGS/$SCRIPT.log" | tee -a $LOG_FILE



# Determine date version
DATE_VERSION=$(date --version > /dev/null 2>&1 && echo "gnu-date" || echo "bsd-date")

if [ "$DATE_VERSION" == "bsd-date" ]
then
    echo "$SCRIPT [`print_time`]: using BSD date" >> $LOG_FILE
elif [ "$DATE_VERSION" == "gnu-date" ]
then
    echo "$SCRIPT [`print_time`]: using GNU date" >> $LOG_FILE
else
    echo "$SCRIPT [`print_time`] [ERROR]: could not figure out version of date: \"$DATE_VERSION\"" 1>&2
    echo "$SCRIPT [`print_time`] [ERROR]: could not figure out version of date: \"$DATE_VERSION\"" >> $LOG_FILE
    exit 1
fi




#####
#   GET START AND END TIMES
#####

# Waveform download log file has time series start/end information
WVFM_LOG_FILE=${PWD}/LOGS/download_waveforms.sh.log
test -f $WVFM_LOG_FILE || { 
    echo "$0 [`print_time`] [ERROR]: could not find waveform log file $WVFM_LOG_FILE with start/end times" 1>&2 ;
    echo "$0 [`print_time`] [ERROR]: could not find waveform log file $WVFM_LOG_FILE with start/end times" >> $LOG_FILE ;
    exit 1;
}
echo "$SCRIPT [`print_time`]: found waveform download log file $WVFM_LOG_FILE with start/end times" >> $LOG_FILE


# Get times of requested window from waveform download log file
echo "$SCRIPT [`print_time`]: getting start/end times from $WVFM_LOG_FILE" >> $LOG_FILE

WINDOW_SECONDS=`grep "WINDOW_SECONDS" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
WINDOW_MINUTES=`echo $WINDOW_SECONDS | awk '{print $1/60}'`
EPOCH_TIME_START=`grep "EPOCH_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START_LOCAL=`grep "CALENDAR_TIME_START_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END_LOCAL=`grep "CALENDAR_TIME_END_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
TIME_ZONE_LOCAL=`grep "TIME_ZONE_LOCAL=" $WVFM_LOG_FILE | awk -F= '{print $2}'`

cat >> $LOG_FILE << EOF
    WINDOW_SECONDS=$WINDOW_SECONDS
    WINDOW_MINUTES=$WINDOW_MINUTES
    CALENDAR_TIME_START=$CALENDAR_TIME_START
    CALENDAR_TIME_END=$CALENDAR_TIME_END
    CALENDAR_TIME_START_LOCAL=$CALENDAR_TIME_START_LOCAL
    CALENDAR_TIME_END_LOCAL=$CALENDAR_TIME_END_LOCAL
    TIME_ZONE_LOCAL=$TIME_ZONE_LOCAL
EOF









#####
#   DOWNLOAD SIGNIFICANT EARTHQUAKES WITHIN TIMESERIES WINDOW
#####


echo "$SCRIPT [`print_time`]: downloading earthquakes from USGS Comprehensive Catalog" >> $LOG_FILE


# Download significant earthquakes
MINSIG=$(grep "^MINSIG=" param.dat | tail -1 | awk -F= '{print $2}')
SIGFROM=param.dat
if [ -z $MINSIG ]
then
    MINSIG=100
    SIGFROM="plot_waveforms.sh"
fi
echo "$SCRIPT [`print_time`]: minimum significance = $MINSIG (from $SIGFROM)" >> $LOG_FILE
COMCAT_URL="https://earthquake.usgs.gov/fdsnws/event/1/query?starttime=${CALENDAR_TIME_START}&endtime=${CALENDAR_TIME_END}&minsig=${MINSIG}&format=csv"
echo "$COMCAT_URL" >> $LOG_FILE
curl "$COMCAT_URL" > query.csv 2>> $LOG_FILE



# Check for server errors...if none, count number of significant earthquakes downloaded
USGS_EQ_QUERY_ERROR=`grep "Internal Server Error" query.csv || echo`
NSIG=0
if [ "$USGS_EQ_QUERY_ERROR" != "" ]
then
    USGS_EQ_QUERY_ERROR="Y"
    echo "$SCRIPT [`print_time`] [WARNING]: could not download earthquakes because of USGS internal server error" >> $LOG_FILE
else
    USGS_EQ_QUERY_ERROR="N"
    NSIG=$(wc query.csv | awk '{print $1-1}')
    echo "$SCRIPT [`print_time`]: downloaded $NSIG significant earthquakes" >> $LOG_FILE
fi




#####
#   PLOT DIMENSIONS
#####


# Get screen dimensions
echo "$SCRIPT [`print_time`]: getting screen dimensions" >> $LOG_FILE

SCREEN_DIMENSIONS=$(xrandr | awk '{if(/ connected/ && /primary/){print $(NF-2),$NF}}')
SCREEN_UNITS=$(echo $SCREEN_DIMENSIONS | awk '{print $1}' | sed -e "s/[0-9]*//")
SCREEN_X=$(echo $SCREEN_DIMENSIONS | sed -e "s/$SCREEN_UNITS//g" | awk '{print $1}')
SCREEN_Y=$(echo $SCREEN_DIMENSIONS | sed -e "s/$SCREEN_UNITS//g" | awk '{print $2}')
cat >> $LOG_FILE << EOF
    SCREEN_UNITS=$SCREEN_UNITS
    SCREEN_X=$SCREEN_X
    SCREEN_Y=$SCREEN_Y
EOF

if [ "$SCREEN_UNITS" == "" ]
then
    SCREEN_UNITS="mm"
    SCREEN_X=406.4
    SCREEN_Y=228.6
fi



# Convert dimensions to inches
echo "$SCRIPT [`print_time`]: converting screen dimensions to inches" >> $LOG_FILE

if [ "$SCREEN_UNITS" == "mm" ]
then
    SCREEN_X=$(echo $SCREEN_X | awk '{print $1/25.4}')
    SCREEN_Y=$(echo $SCREEN_Y | awk '{print $1/25.4}')
else
    echo "$SCRIPT [`print_time`] [ERROR]: unknown screen dimension unit $SCREEN_UNITS" 1>&2
    echo "$SCRIPT [`print_time`] [ERROR]: unknown screen dimension unit $SCREEN_UNITS" >> $LOG_FILE
    echo "Tell Matt to fix this" 1>&2
    echo "Tell Matt to fix this" >> $LOG_FILE
    exit 1
fi
cat >> $LOG_FILE << EOF
    SCREEN_X=$SCREEN_X
    SCREEN_Y=$SCREEN_Y
EOF



# Set paper size to be screen dimensions
echo "$SCRIPT [`print_time`]: setting PS_MEDIA to ${SCREEN_X}ix${SCREEN_Y}i" >> $LOG_FILE

gmt set PS_MEDIA ${SCREEN_X}ix${SCREEN_Y}i




# Plot dimensions
WHITESPACE_X=0.25
if [ $NSIG -ge 1 ]
then
    WHITESPACE_Y_TOP=0.85
else
    WHITESPACE_Y_TOP=0.25
fi
WHITESPACE_Y_BOT=0.25
X_AXIS_HGT=0.7
TOTAL_WID=$(echo $SCREEN_X | awk '{print $1-'$WHITESPACE_X'*2}')                        # Total plot width (in)
TOTAL_HGT=$(echo $SCREEN_Y | awk '{print $1-'$WHITESPACE_Y_TOP'-'$WHITESPACE_Y_BOT'}')  # Total plot height (in)
echo "$SCRIPT [`print_time`]: setting plot width to ${TOTAL_WID} in" >> $LOG_FILE
echo "$SCRIPT [`print_time`]: setting plot height to ${TOTAL_HGT} in" >> $LOG_FILE










#####
#   PLOT TIME SERIES
#####


# Postscript file name
PSFILE=waveforms.ps
echo "$SCRIPT [`print_time`]: setting PostScript file name to \"$PSFILE\"" >> $LOG_FILE



# Number of seismograms to plot
N=`ls SAC/*.sac | wc | awk '{print $1}'`                                        # Number of seismograms to plot
echo "$SCRIPT [`print_time`]: plotting $N seismograms" >> $LOG_FILE



# Seismogram dimensions
TRACE_WID=$TOTAL_WID                                                            # Width of each seismogram (in)
TRACE_SHFT_HGT=`echo $TOTAL_HGT $X_AXIS_HGT $N | awk '{print ($1-$2)/$3}'`      # Vertical spacing between each seismogram (in)
TRACE_RATIO=1.00                                                                # Relative height of each seismogram
TRACE_HGT=`echo $TRACE_SHFT_HGT $TRACE_RATIO | awk '{print $1*$2}'`             # Height of each seismogram (in)
echo "$SCRIPT [`print_time`]: setting each trace width to ${TRACE_WID} in" >> $LOG_FILE
echo "$SCRIPT [`print_time`]: setting each trace height to ${TRACE_HGT} in" >> $LOG_FILE



# Vertical spacing between each seismogram
SHFT=$TRACE_SHFT_HGT
echo "$SCRIPT [`print_time`]: setting vertical shift between traces to ${SHFT} in" >> $LOG_FILE



# Cartesian axes
PROJ=-JX${TRACE_WID}i/${TRACE_HGT}i
echo "$SCRIPT [`print_time`]: GMT projection option for each trace: \"$PROJ\"" >> $LOG_FILE



# Initialize figure
echo "$SCRIPT [`print_time`]: initializing figure $PSFILE" | tee -a $LOG_FILE

SHFT_Y=$(echo $TOTAL_HGT $TRACE_HGT | awk '{print $1-$2-$3}')
gmt psxy -T -K -X${WHITESPACE_X}i -Y${SHFT_Y}i -P > $PSFILE




# Plot all waveforms, starting with CSUB station
STATION_LIST_1=$(ls SAC/*.sac | grep "BAK." || echo)
STATION_LIST_2=$(ls SAC/*.sac | grep -v "BAK." || echo)
for TRACE in $STATION_LIST_1 $STATION_LIST_2
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
                printf("%15.6f%20.6e\n"), t,v
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


echo "$SCRIPT [`print_time`]: plotting significant earthquakes" | tee -a $LOG_FILE



# Shift origin back up one waveform
gmt psxy -T -K -O -Y${SHFT}i >> $PSFILE



# New frame parameters for significant earthquake bars
echo "$SCRIPT [`print_time`]: setting new GMT projection and region parameters for plotting significant earthquakes" >> $LOG_FILE
HGT=`echo $N $TRACE_HGT $SHFT | awk '{print ($1-1)*$3+$2}'`
PROJ=-JX${TOTAL_WID}i/${HGT}i
LIMS=-R0/$WINDOW_MINUTES/0/1
cat >> $LOG_FILE << EOF
    PROJ=$PROJ
    LIMS=$LIMS
EOF





# If no server error and NSIG>=1, extract events and plot timing on waveforms
if [ $NSIG -ge 1 ]
then

    # Reverse order of events
    echo "$SCRIPT [`print_time`]: reversing order of significant earthquake file" >> $LOG_FILE
    awk '{line[NR]=$0}END{for(i=NR;i>1;i--){print line[i]}}' query.csv > j
    mv j query.csv


    # Save significant earthquakes
    echo "$SCRIPT [`print_time`]: saving significant earthquakes in sig_eq.tmp" >> $LOG_FILE
    awk -F, '{print $1,$2,$3,$4,$5}' query.csv > sig_eq.tmp
    awk '{print $5}' sig_eq.tmp > mag.tmp
    grep -o "\".*\"" query.csv > sig_eq_name.tmp



    # Calculate number of seconds from start time to earthquake
    echo "$SCRIPT [`print_time`]: calculating earthquake time in seconds from start of timeseries window" >> $LOG_FILE
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
    echo "$SCRIPT [`print_time`]: plotting $NSIG significant earthquakes" >> $LOG_FILE

    paste time.tmp mag.tmp |\
        awk '{
            t = $1/60

            if ($2>=8) {
                pen = 3+($2-8)
                color = "red@15"
            } else if ($2>=7) {
                pen = 2+($2-7)
                color = "red@30"
            } else if ($2>=6) {
                pen = 1+($2-6)
                color = "red@40"
            } else if ($2>=5.5) {
                pen = 1
                color = "orange@40"
            } else if ($2>=5.0) {
                pen = 1
                color = "palegreen3@40"
            } else {
                pen = 1
                color = "lightsteelblue3@40"
            }

            printf("> -W%.2fp,%s\n"),pen,color
            print t, 0
            print t, 1

        }' |\
        gmt psxy $PROJ $LIMS -K -O >> $PSFILE

    # Label significant earthquakes
    paste time.tmp mag.tmp sig_eq_name.tmp |\
        awk '{
            time = $1/60
            mag = $2
            split($0,name,"\"")

            if ($2>=8) {
                color = "red@15"
            } else if ($2>=7) {
                color = "red@30"
            } else if ($2>=6) {
                color = "red@40"
            } else if ($2>=5.5) {
                color = "orange@40"
            } else if ($2>=5.0) {
                color = "palegreen3@40"
            } else {
                color = "lightsteelblue3@40"
            }

            printf("%.3f %.3f 8,0,%s M %.1f, %s\n"),time,1,color,mag,name[2]

        }' |\
        gmt pstext $PROJ $LIMS -F+f+jLM+a30 -D0.02i/0.07i -N -K -O >> $PSFILE

    # echo No significant earthquakes | gmt pstext $PROJ $LIMS -F+f10,2,red@40+cTL -D0.25i/0.25i -N -K -O >> $PSFILE

    # Remove temporary files
    rm mag.tmp time.tmp sig_eq_name.tmp

fi








#####
#   FINALIZE PLOT & CLEAN UP
#####

echo "$SCRIPT [`print_time`]: plotting time axis" | tee -a $LOG_FILE

# Label and annotate x-axis (time)
LIMS=-R-$WINDOW_MINUTES/0/0/1
gmt psbasemap $PROJ $LIMS -Bxa5+l"Time (Minutes)" -BS -K -O \
    --FONT_LABEL=20p \
    --FONT_ANNOT_PRIMARY=14p >> $PSFILE


# Label starting and ending times
echo "$SCRIPT [`print_time`]: labeling start and end times" >> $LOG_FILE
echo $CALENDAR_TIME_START_LOCAL $TIME_ZONE_LOCAL |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f11,2+cBL -D0/-0.55i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_END_LOCAL $TIME_ZONE_LOCAL |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f11,2+cBR -D0/-0.55i -N -K -O >> $PSFILE



# # Full frame around image (usually leave commented out)
# echo "$SCRIPT [`print_time`]: plotting full frame around image" >> $LOG_FILE
# gmt psxy -T -Y-${X_AXIS_HGT}i -K -O >> $PSFILE
# gmt psbasemap -JX${TOTAL_WID}i/${TOTAL_HGT}i $LIMS -Bf -K -O >> $PSFILE



# Finalize PostScript
gmt psxy -T -O >> $PSFILE



# Convert PostScript
echo "$SCRIPT [`print_time`]: converting PostScript to PNG and PDF" | tee -a $LOG_FILE
gmt psconvert $PSFILE -Tg -E300 -Qg4

# gmt psconvert $PSFILE -Tj -E720
gmt psconvert $PSFILE -Tf


# Clean up
echo "$SCRIPT [`print_time`]: cleaning up" | tee -a $LOG_FILE
rm $PSFILE
rm gmt.history gmt.conf
rm query.csv
rm sig_eq.tmp




echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE
