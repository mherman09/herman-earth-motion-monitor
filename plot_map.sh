#!/bin/bash



#####
#   INITIALIZE LOG FILE
#####
PWD=`pwd`
LOG_FILE=${PWD}/$0.log
echo starting $0 > $LOG_FILE
echo Current time in local time zone: `date "+%Y-%m-%dT%H:%M:%S"` >> $LOG_FILE

# Check for server errors in earthquake download...
USGS_EQ_QUERY_ERROR=`grep "Internal Server Error" query.csv`
if [ "$USGS_EQ_QUERY_ERROR" != "" ]
then
    USGS_EQ_QUERY_ERROR="Y"
else
    USGS_EQ_QUERY_ERROR="N"
fi


# Do all the work in the MAP directory
test -d MAP || mkdir MAP
cd MAP


# GMT settings
gmt set PS_MEDIA 100ix100i
gmt set MAP_FRAME_TYPE plain


# Variables
PSFILE=map.ps


# Initialize map
gmt psxy -T -K > $PSFILE


for COORD in -90,0,0,20 \
             0,0,5.1,0 \
             90,0,5.1,0 \
             180,0,5.1,0 \
             0,90,-7.7,4.5 \
             0,-90,0,-9.0
do

    LON0=`echo $COORD | awk -F, '{print $1}'`
    LAT0=`echo $COORD | awk -F, '{print $2}'`
    XSHFT=`echo $COORD | awk -F, '{print $3}'`
    YSHFT=`echo $COORD | awk -F, '{print $4}'`

    PROJ=-JA$LON0/$LAT0/5i
    LIMS=-Rg

    # Shift origin
    gmt psxy -T -X${XSHFT}i -Y${YSHFT}i -K -O >> $PSFILE

    # Coastline
    gmt pscoast $PROJ $LIMS -Di -G255 -S149/181/192 -A0/0/1 -K -O >> $PSFILE

    # Map frame
    gmt psbasemap $PROJ $LIMS -Bxg30 -Byg30 -K -O --MAP_FRAME_PEN=0.5p --MAP_GRID_PEN=0.25p,105@40 >> $PSFILE

    # Station locations
    for TRACE in ../SAC/*.CI.*.sac ../SAC/*.IU.*.sac
    do

        echo getting station info for $TRACE >> $LOG_FILE

        # Get directory name and ASCII seismogram file name
        DIR=`dirname $TRACE`
        ASCII_FILE=`basename $TRACE .sac`.dat

        # Plot station name
        KSTNM=`saclhdr -KSTNM $TRACE`
        STLO=`saclhdr -STLO $TRACE`
        STLA=`saclhdr -STLA $TRACE`
        DIST=`lola2distaz -c $LON0 $LAT0 $STLO $STLA | awk '{print $1/111.19}'`
        PLOT=`echo $DIST | awk '{if($1<=90){print "Y"}else{print "N"}}'`
        if [ $PLOT == "Y" ]
        then
            echo $STLO $STLA | gmt psxy $PROJ $LIMS -Si0.1i -W1p -Gred -N -K -O >> $PSFILE
            echo $STLO $STLA $KSTNM | gmt pstext $PROJ $LIMS -F+f7,1+jCB -D0/0.07i -N -K -O >> $PSFILE
        fi
    done

    # Significant earthquakes
    if [ "$USGS_EQ_QUERY_ERROR" == "N" ]
    then
        # echo $LON0 $LAT0
        gmt makecpt -T0/100/10 -Cplasma -I -D > dep.cpt
        awk '{print '$LON0','$LAT0',$3,$2}' ../sig_eq.tmp |\
            lola2distaz -f stdin | awk '{print $1}' > dist.tmp
        paste dist.tmp ../sig_eq.tmp |\
            awk '{if($1/111.19<=90){print $4,$3,$5,$6*$6*$6*0.0016}}' |\
            gmt psxy $PROJ $LIMS -Sci -W1p -Cdep.cpt -N -K -O >> $PSFILE
        # paste dist.tmp ../sig_eq.tmp |\
        #     awk '{if($1/111.19<=90){print $4,$3,$5,$6*$6*$6*0.0016}}'
    fi
done

# Scale
cat > seis_scale.tmp << EOF
0.5 4.0
1.0 5.0
1.6 6.0
2.4 7.0
3.4 8.0
4.8 9.0
EOF
awk '{print $1,2.0,$2^3*0.0016}' seis_scale.tmp |\
    gmt psxy -JX1i -R0/1/0/1 -W1p -Sci -X6.0i -N -K -O >> $PSFILE
awk '{print $1,2.0+$2^3*0.0016/2,11+($2-4)*1.5,$2}' seis_scale.tmp |\
    gmt pstext -J -R -F+f+jCB -D0/0.05i -N -K -O >> $PSFILE
gmt psscale -Dx-9.5i/0.5i+w-4.0i/0.25i -Cdep.cpt -Ba20+l"Depth (km)" -K -O >> $PSFILE

# Finalize map
gmt psxy -T -O >> $PSFILE

gmt psconvert $PSFILE -Tg -A -E300
mv map.png ..
rm $PSFILE

cd ..