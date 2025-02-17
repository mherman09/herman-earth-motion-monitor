#!/bin/bash


set -e

# Determine date version
DATE_VERSION=`date --version > /dev/null 2>&1 && echo "gnu-date" || echo "bsd-date"`

# if [ "$DATE_VERSION" == "bsd-date" ]
# then
#     echo Using BSD date >> $LOG_FILE
# elif [ "$DATE_VERSION" == "gnu-date" ]
# then
#     echo Using GNU date >> $LOG_FILE
# else
#     echo Could not figure out which date version to use...exiting 1>&2
#     exit 1
# fi



#####
#   PLOT TIME SERIES
#####

gmt set PS_MEDIA 100ix100i

# Postscript file name
PSFILE=waveforms.ps

# Seismogram dimensions
WID=10
HGT=0.6
PROJ=-JX${WID}i/${HGT}i


# Shift between plots
SHFT=0.65


# Initialize figure
gmt psxy -T -K -Y50i > $PSFILE


# Get times of requested window from waveform download log file
EPOCH_TIME_START=`grep "EPOCH_TIME_START" download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START" download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END" download_waveforms.sh.log | awk -F"=" '{print $2}'`


# Number of seismograms to plot
N=`ls SAC/*.sac | wc | awk '{print $1}'`


# Plot all waveforms, starting with California stations
for TRACE in SAC/*.CI.*.sac SAC/*.IU.*.sac
do

    echo plotting trace $TRACE

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
    NZDATE="${NZYEAR}-${NZJDAY}T${NZHOUR}:${NZMIN}:${NZSEC}"
    if [ "$DATE_VERSION" == "bsd-date" ]
    then
        EPOCH_TIME_TRACE_START=`date -ju -f "%Y-%jT%H:%M:%S" "$NZDATE" "+%s"`
    elif [ "$DATE_VERSION" == "gnu-date" ]
    then
        EPOCH_TIME_TRACE_START=`date -u -d "$NZDATE" "+%s"`
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
        gmt psxy $PROJ $LIMS -W0.5p -K -O >> $PSFILE

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
HGT=`echo $N $HGT $SHFT | awk '{print ($1-1)*$3+$2}'`
PROJ=-JX${WID}i/${HGT}i
LIMS=-R0/$WINDOW_MINUTES/0/1

# Plot timing of significant earthquakes
MINSIG=400
COMCAT_URL="https://earthquake.usgs.gov/fdsnws/event/1/query?starttime=${CALENDAR_TIME_START}&endtime=${CALENDAR_TIME_END}&minsig=${MINSIG}&format=csv"
echo "$COMCAT_URL"
curl "$COMCAT_URL" > query.csv
awk -F, '{if(NR>1){print $1,$2,$3,$4,$5}}' query.csv > sig_eq.tmp
awk '{print $5}' sig_eq.tmp > mag.tmp
if [ "$DATE_VERSION" == "bsd-date" ]
then
    awk -F"." '{print $1}' sig_eq.tmp | xargs date -ju -f "%Y-%m-%dT%H:%M:%S" "+%s" |\
        awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
elif [ "$DATE_VERSION" == "gnu-date" ]
then
    awk -F"." '{print $1}' sig_eq.tmp | xargs date -u -d "+%s" |\
        awk '{print $1-'$EPOCH_TIME_START'}' > time.tmp
else
    echo Could not figure out which date version to use...exiting 1>&2
    exit 1
fi

paste time.tmp mag.tmp |\
    awk 'BEGIN{n='$N'-2.5}{
        t = $1/60
        if ($2>=8) {print "> -W3p,red@10";print t,0;print t,1}
        else if ($2>=7) {print "> -W2p,red@20";print t,0;print t,1}
        else if ($2>=6) {print "> -W1p,red@30";print t,0;print t,1}
        else {print "> -W0.5p,red@50";print t,0;print t,1}
    }' |\
    gmt psxy $PROJ $LIMS -K -O >> $PSFILE
rm sig_eq.tmp mag.tmp time.tmp


# Plot map frame
LIMS=-R-$WINDOW_MINUTES/0/0/1
gmt psbasemap $PROJ $LIMS -Bxa5+l"Time (Minutes)" -BS -K -O >> $PSFILE
echo $CALENDAR_TIME_END | gmt pstext $PROJ $LIMS -F+f8,2+cBR -D0/-0.45i -N -K -O >> $PSFILE
# gmt psbasemap $PROJ $LIMS -Bf -K -O >> $PSFILE



gmt psxy -T -O >> $PSFILE

gmt psconvert $PSFILE -Tg -A
rm $PSFILE
rm gmt.history gmt.conf