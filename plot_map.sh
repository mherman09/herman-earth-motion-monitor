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

# Labels
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" ../download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END=" ../download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_START_LOCAL=`grep "CALENDAR_TIME_START_LOCAL=" ../download_waveforms.sh.log | awk -F"=" '{print $2}'`
CALENDAR_TIME_END_LOCAL=`grep "CALENDAR_TIME_END_LOCAL=" ../download_waveforms.sh.log | awk -F"=" '{print $2}'`
TIME_ZONE=`grep "TIME_ZONE=" ../download_waveforms.sh.log | awk -F= '{print $2}'`
echo Earthquakes Around The World | gmt pstext -JX1i -R0/1/0/1 -F+f32,1+cTL -Xa0.5i -Ya28.0i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_START @%2%to@%% $CALENDAR_TIME_END \(UTC\)|\
    gmt pstext -JX1i -R0/1/0/1 -F+f20,0+cTL -Xa0.5i -Ya27.35i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_START_LOCAL @%2%to@%% $CALENDAR_TIME_END_LOCAL \($TIME_ZONE\)|\
    gmt pstext -JX1i -R0/1/0/1 -F+f20,0+cTL -Xa0.5i -Ya26.9i -N -K -O >> $PSFILE

for COORD in -90,0,0,20 \
             0,0,5.1,20 \
             90,0,10.2,20 \
             180,0,15.3,20 \
             0,90,7.6,24.5 \
             0,-90,7.6,15.5
do

    LON0=`echo $COORD | awk -F, '{print $1}'`
    LAT0=`echo $COORD | awk -F, '{print $2}'`
    XSHFT=`echo $COORD | awk -F, '{print $3}'`
    YSHFT=`echo $COORD | awk -F, '{print $4}'`
    SHFT="-Xa${XSHFT}i -Ya${YSHFT}i"

    PROJ=-JA$LON0/$LAT0/5i
    LIMS=-Rg


    # Coastline
    gmt pscoast $PROJ $LIMS -Di -G255 -S149/181/192 -A0/0/1 $SHFT -K -O >> $PSFILE

    # Map frame
    gmt psbasemap $PROJ $LIMS -Bxg30 -Byg30 $SHFT -K -O --MAP_FRAME_PEN=0.5p --MAP_GRID_PEN=0.25p,105@40 >> $PSFILE

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
            echo $STLO $STLA | gmt psxy $PROJ $LIMS -Si0.1i -W1p -Gred -N $SHFT -K -O >> $PSFILE
            echo $STLO $STLA $KSTNM | gmt pstext $PROJ $LIMS -F+f7,1+jCB -D0/0.07i -N $SHFT -K -O >> $PSFILE
        fi
    done

    # Significant earthquakes
    if [ "$USGS_EQ_QUERY_ERROR" == "N" ]
    then
        echo Earthquakes plotted on map centered at LON0=$LON0 LAT0=$LAT0
        gmt makecpt -T0/100/10 -Cplasma -I -D > dep.cpt
        awk '{print '$LON0','$LAT0',$3,$2}' ../sig_eq.tmp |\
            lola2distaz -f stdin | awk '{print $1}' > dist.tmp
        paste dist.tmp ../sig_eq.tmp |\
            awk '{
                if ($1/111.19<=90) {
                    print $4,$3,$5,$6*$6*$6*0.0016
                    printf("%10.3f%10.3f%8.2f%7.1f\n"),$4,$3,$5,$6 > "/dev/stderr"
                }
            }END{print "" > "/dev/stderr"}' |\
            gmt psxy $PROJ $LIMS -Sci -W1p -Cdep.cpt $SHFT -N -K -O >> $PSFILE
    fi
done

# Magnitude Legend
echo 0 1 Magnitude | gmt pstext -JX1i -R0/1/0/1 -F+f28,1+jCT -Xa14.5i -Ya28.0i -D0.15i/0 -N -K -O >> $PSFILE
cat > seis_scale.tmp << EOF
2.20 9.0
1.38 8.0
0.76 7.0
0.37 6.0
0.14 5.0
0.00 4.0
EOF
SHFT="-Xa14.5i -Ya25.6i"
awk '{print 0.0,$1,$2^3*0.0016}' seis_scale.tmp |\
    gmt psxy -JX1i -R0/1/0/1 -W1p -G235 -Sci $SHFT -N -K -O >> $PSFILE
awk '{print 0.0+$2^3*0.0016/2,$1,11+($2-4)*1.5,$2}' seis_scale.tmp |\
    gmt pstext -J -R -F+f+jLM -D0.05i/0 $SHFT -N -K -O >> $PSFILE

# Depth Legend
echo 0 1 Depth \(km\) | gmt pstext -JX1i -R0/1/0/1 -F+f28,1+jCT -Xa17.5i -Ya28.0i -D0.15i/0 -N -K -O >> $PSFILE
gmt psscale -Dx17.5i/25.5i+w-2.8i/0.25i -Cdep.cpt -Ba20 -K -O --FONT_ANNOT=20 >> $PSFILE

# Earthquake list
PROJ=-JX7i/4i
LIMS=-R0/7/0/4
SHFT="-Xa13.0i -Ya15.5i"
echo 0 4.0 Event List |\
    gmt pstext $PROJ $LIMS -F+f28,1+jLT $SHFT -N -K -O >> $PSFILE
echo 0 3.4 "Origin(UTC) Lat     Lon      Dep(km) Mag" |\
    gmt pstext $PROJ $LIMS -F+f20,8+jLT $SHFT -N -K -O >> $PSFILE
awk '{
    ot = substr($1,12,8)
    lo = $3
    la = $2
    dp = $4
    mg = $5
    printf("%.1f  %.3f  %-11s\ %-8.2f%-8.2f %-8.2f%-7.1f\n"), 0,3.40-NR*0.35,ot,la,lo,dp,mg
}' ../sig_eq.tmp |\
    gmt pstext $PROJ $LIMS -F+f20,8+jLT $SHFT -N -K -O >> $PSFILE
# gmt psbasemap $PROJ $LIMS -Bxg0.2 -Byg0.2 $SHFT -K -O --MAP_GRID_PEN=0.25p,105 >> $PSFILE
# gmt psbasemap $PROJ $LIMS -Bxg1 -Byg1 $SHFT -K -O --MAP_GRID_PEN=1p >> $PSFILE

# Finalize map
gmt psxy -T -O >> $PSFILE

gmt psconvert $PSFILE -Tg -A -E300
mv map.png ..
rm $PSFILE

cd ..