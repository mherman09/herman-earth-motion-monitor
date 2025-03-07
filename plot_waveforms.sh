#!/bin/bash


set -e

# Determine date version
DATE_VERSION=`date --version > /dev/null 2>&1 && echo "gnu-date" || echo "bsd-date"`


#####
#   INITIALIZE LOG FILE
#####
PWD=`pwd`
LOG_FILE=${PWD}/$0.log
echo starting $0 > $LOG_FILE
echo Current time in local time zone: `date "+%Y-%m-%dT%H:%M:%S"` >> $LOG_FILE






#####
#   PLOT TIME SERIES
#####

gmt set PS_MEDIA 100ix100i

# Postscript file name
PSFILE=waveforms.ps

# Seismogram dimensions
TOTAL_WID=16                                          # Total plot width (in)
TOTAL_HGT=9                                           # Total plot height (in)
N=`ls SAC/*.sac | wc | awk '{print $1}'`              # Number of seismograms to plot
TRACE_WID=$TOTAL_WID
TRACE_SHFT_HGT=`echo $TOTAL_HGT $N | awk '{print $1/$2}'`
TRACE_RATIO=1.0
TRACE_HGT=`echo $TRACE_SHFT_HGT $TRACE_RATIO | awk '{print $1*$2}'`
SHFT=$TRACE_SHFT_HGT
PROJ=-JX${TRACE_WID}i/${TRACE_HGT}i


# Initialize figure
gmt psxy -T -K -Y50i > $PSFILE


# Get times of requested window from waveform download log file
EPOCH_TIME_START=`grep "EPOCH_TIME_START" download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START" download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END" download_waveforms.sh.log | awk -F"=" '{print $2}'`
TIME_ZONE=`grep "TIME_ZONE=" download_waveforms.sh.log | awk -F= '{print $2}'`

# Plot all waveforms, starting with California stations
for TRACE in SAC/*.CI.*.sac SAC/*.IU.*.sac
do

    echo plotting trace $TRACE >> $LOG_FILE

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
                print t,v
            }
        }
    }' $DIR/$ASCII_FILE |\
        gmt psxy $PROJ $LIMS -W0.5p,65 -K -O >> $PSFILE

    # Plot station name
    KSTNM=`saclhdr -KSTNM $TRACE`
    DESCRIPTION=`grep DESCRIPTION SAC/PZRESP*.$KSTNM.* | awk -F":" '{print $2}'`
    echo "$DESCRIPTION ($KSTNM)" | gmt pstext $PROJ $LIMS -F+f12,3+cTR -D-0.05i/0 -K -O >> $PSFILE

    # Plot frame
    # gmt psbasemap $PROJ $LIMS -Bxf -Byf -K -O >> $PSFILE

    # Shift down to plot next waveform
    gmt psxy -T -K -O -Y-${SHFT}i >> $PSFILE
done


# Shift back up
gmt psxy -T -K -O -Y${SHFT}i >> $PSFILE

# New map frame parameters
WINDOW_SECONDS=`grep "WINDOW_SECONDS" download_waveforms.sh.log | awk -F"=" '{print $2}'`
WINDOW_MINUTES=`echo $WINDOW_SECONDS | awk '{print $1/60}'`
N=`echo $N | awk '{print $1}'`
HGT=`echo $N $TRACE_HGT $SHFT | awk '{print ($1-1)*$3+$2}'`
PROJ=-JX${TOTAL_WID}i/${HGT}i
LIMS=-R0/$WINDOW_MINUTES/0/1

# Plot timing of significant earthquakes
# Download earthquakes
MINSIG=100 # Minimimum significance (https://earthquake.usgs.gov/earthquakes/browse/significant.php#sigdef)
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
    awk -F, '{if(NR>1){print $1,$2,$3,$4,$5}}' query.csv > sig_eq.tmp
    awk '{print $5}' sig_eq.tmp > mag.tmp
    if [ "$DATE_VERSION" == "bsd-date" ]
    then
        awk -F"." '{print $1}' sig_eq.tmp | xargs date -ju -f "%Y-%m-%dT%H:%M:%S" "+%s" |\
            awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
    elif [ "$DATE_VERSION" == "gnu-date" ]
    then
        awk -F"." '{print $1}' sig_eq.tmp | xargs -I ^ date -d ^ "+%s" |\
            awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
    else
        echo Could not figure out which date version to use...exiting 1>&2
        exit 1
    fi

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
    rm mag.tmp time.tmp
fi


# Plot map frame
LIMS=-R-$WINDOW_MINUTES/0/0/1
gmt psbasemap $PROJ $LIMS -Bxa5+l"Time (Minutes)" -BS -K -O >> $PSFILE
echo $CALENDAR_TIME_START $TIME_ZONE |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f8,2+cBL -D0/-0.45i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_END $TIME_ZONE |\
    sed -e "s/T/ /" |\
    gmt pstext $PROJ $LIMS -F+f8,2+cBR -D0/-0.45i -N -K -O >> $PSFILE
# gmt psbasemap -JX${TOTAL_WID}i/${TOTAL_HGT}i $LIMS -Bf -K -O >> $PSFILE



gmt psxy -T -O >> $PSFILE

gmt psconvert $PSFILE -Tg -A
rm $PSFILE
rm gmt.history gmt.conf