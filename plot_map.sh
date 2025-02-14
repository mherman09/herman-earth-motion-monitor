#!/bin/bash

gmt set PS_MEDIA 100ix100i

PSFILE=map.ps

PROJ=-JN160/10i
LIMS=-Rg

gmt psxy -T -K > $PSFILE

# Coastline
gmt pscoast $PROJ $LIMS -Dc -W0.5p,145 -A0/0/1 -S225/235/255 -G255/255/225 -K -O >> $PSFILE

# Significant earthquakes
awk '{print $3,$2,$5*$5*$5*0.001}' sig_eq.tmp |\
    gmt psxy $PROJ $LIMS -Sci -W1p -Gyellow -K -O >> $PSFILE

# Stations
for TRACE in SAC/*.CI.*.sac SAC/*.IU.*.sac
do

    echo getting station info for $TRACE

    # Get directory name and ASCII seismogram file name
    DIR=`dirname $TRACE`
    ASCII_FILE=`basename $TRACE .sac`.dat

    # Plot station name
    KSTNM=`saclhdr -KSTNM $TRACE`
    STLO=`saclhdr -STLO $TRACE`
    STLA=`saclhdr -STLA $TRACE`
    echo $STLO $STLA | gmt psxy $PROJ $LIMS -Si0.1i -W1p -Gred -K -O >> $PSFILE
    echo $STLO $STLA $KSTNM | gmt pstext $PROJ $LIMS -F+f7,1+jCB -D0/0.07i -K -O >> $PSFILE

done


# Plot map frame
gmt psbasemap $PROJ $LIMS -Bxf30 -Byf30 -K -O >> $PSFILE

gmt psxy -T -O >> $PSFILE

gmt psconvert $PSFILE -Tg -A
rm $PSFILE
rm gmt.history gmt.conf