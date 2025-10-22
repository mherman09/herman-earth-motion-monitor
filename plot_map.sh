#!/bin/bash



#####
#   INITIALIZE LOG FILE
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



# Waveform download log file has time series start/end information
WVFM_LOG_FILE=${PWD}/LOGS/download_waveforms.sh.log
test -f $WVFM_LOG_FILE || { echo "$0 [ERROR]: could not find waveform log file $WVFM_LOG_FILE" 1>&2; exit 1; }









#####
#   DOWNLOAD SIGNIFICANT EARTHQUAKES
#####


# Time window saved in waveform download log file
echo "$SCRIPT [`print_time`]: extracting timing information from $WVFM_LOG_FILE" | tee -a $LOG_FILE
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START_LOCAL=`grep "CALENDAR_TIME_START_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END_LOCAL=`grep "CALENDAR_TIME_END_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
TIME_ZONE_LOCAL=`grep "TIME_ZONE_LOCAL=" $WVFM_LOG_FILE | awk -F= '{print $2}'`

cat > j << EOF
CALENDAR_TIME_START=$CALENDAR_TIME_START
CALENDAR_TIME_END=$CALENDAR_TIME_END
CALENDAR_TIME_START_LOCAL=$CALENDAR_TIME_START_LOCAL
CALENDAR_TIME_END_LOCAL=$CALENDAR_TIME_END_LOCAL
TIME_ZONE_LOCAL=$TIME_ZONE_LOCAL
EOF
cat j | tee -a $LOG_FILE
rm j



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



# If no server error, extract events
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

fi






#####
#   PLOT SIGNIFICANT EARTHQUAKES
#####

# Do all the work in the MAP directory
echo "$SCRIPT [`print_time`]: working in MAP directory" | tee -a $LOG_FILE
test -d MAP || mkdir MAP
cd MAP



# GMT settings
echo "$SCRIPT [`print_time`]: setting GMT parameters" | tee -a $LOG_FILE
gmt set PS_MEDIA 100ix100i
gmt set MAP_FRAME_TYPE plain



# Variables
PSFILE=map.ps



# Initialize map
echo "$SCRIPT [`print_time`]: initializing PostScript file" | tee -a $LOG_FILE
gmt psxy -T -K > $PSFILE



# Labels
echo "$SCRIPT [`print_time`]: plotting figure labels" | tee -a $LOG_FILE
echo Earthquakes Around The World | gmt pstext -JX1i -R0/1/0/1 -F+f32,1+cTL -Xa0.5i -Ya28.0i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_START @%2%to@%% $CALENDAR_TIME_END \(UTC\)|\
    gmt pstext -JX1i -R0/1/0/1 -F+f20,0+cTL -Xa0.5i -Ya27.35i -N -K -O >> $PSFILE
echo $CALENDAR_TIME_START_LOCAL @%2%to@%% $CALENDAR_TIME_END_LOCAL \($TIME_ZONE_LOCAL\)|\
    gmt pstext -JX1i -R0/1/0/1 -F+f20,0+cTL -Xa0.5i -Ya26.9i -N -K -O >> $PSFILE




# Plot map panels
echo "$SCRIPT [`print_time`]: plotting maps" | tee -a $LOG_FILE
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

    # Grid labels
    if [ $LAT0 == 0 ]
    then
        LON0_MINUS_60=`echo $LON0 | awk '{print $1-60}'`
        LON0_PLUS_60=`echo $LON0 | awk '{print $1+60}'`
        grid -x $LON0_MINUS_60 $LON0_PLUS_60 -dx 30 -y 0 0 -dy 30 |\
            awk '{
                if ($1>=0) {
                    printf("%14.6e %14.6e %.0f\\260E\n"),$1,$2,$1
                } else {
                    printf("%14.6e %14.6e %.0f\\260W\n"),$1,$2,-$1
                }
            }' |\
            gmt pstext $PROJ $LIMS -F+f5,2,95+jBL -D0.02i/0.02i -t40 $SHFT -K -O >> $PSFILE
        grid -x $LON0 $LON0 -dx 30 -y -60 60 -dy 30 |\
            awk '{
                if ($2>=0) {
                    printf("%14.6e %14.6e %.0f\\260N\n"),$1,$2,$2
                } else {
                    printf("%14.6e %14.6e %.0f\\260S\n"),$1,$2,-$2
                }
            }' |\
            gmt pstext $PROJ $LIMS -F+f5,2,95+jTR -D-0.02i/-0.02i -t40 $SHFT -K -O >> $PSFILE
    fi

    # Station locations
    echo "$SCRIPT [`print_time`]: plotting seismic stations shown in waveforms.png" | tee -a $LOG_FILE
    for TRACE in ../SAC/*.CI.*.sac ../SAC/*.IU.*.sac
    do

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
        echo "$SCRIPT [`print_time`]: center coordinates: LON0=$LON0 LAT0=$LAT0" | tee -a $LOG_FILE
        gmt makecpt -T0/100/10 -Cplasma -I -D > dep.cpt
        awk '{print '$LON0','$LAT0',$3,$2}' ../sig_eq.tmp |\
            lola2distaz -f stdin | awk '{print $1}' > dist.tmp
        paste dist.tmp ../sig_eq.tmp |\
            awk '{
                if ($1/111.19<=90) {
                    print $4,$3,$5,$6*$6*$6*0.0016
                    printf("%10.3f%10.3f%8.2f%7.1f\n"),$4,$3,$5,$6 > "/dev/stderr"
                }
            }' |\
            gmt psxy $PROJ $LIMS -Sci -W1p -Cdep.cpt $SHFT -N -K -O >> $PSFILE
    fi

done



# Magnitude Legend
echo "$SCRIPT [`print_time`]: plotting magnitude legend" | tee -a $LOG_FILE
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
echo "$SCRIPT [`print_time`]: plotting depth legend" | tee -a $LOG_FILE
echo 0 1 Depth \(km\) | gmt pstext -JX1i -R0/1/0/1 -F+f28,1+jCT -Xa17.5i -Ya28.0i -D0.15i/0 -N -K -O >> $PSFILE
gmt psscale -Dx17.5i/25.5i+w-2.8i/0.25i -Cdep.cpt -Ba20 -K -O --FONT_ANNOT=20 >> $PSFILE



# Earthquake list
echo "$SCRIPT [`print_time`]: plotting text list of earthquakes on map" | tee -a $LOG_FILE
PROJ=-JX7i/4i
LIMS=-R0/7/0/4
SHFT="-Xa13.0i -Ya15.5i"
echo 0 4.0 Event List |\
    gmt pstext $PROJ $LIMS -F+f28,1+jLT $SHFT -N -K -O >> $PSFILE
echo 0 3.4 "Origin(UTC) Latitude Longitude Depth(km) Magnitude" |\
    gmt pstext $PROJ $LIMS -F+f16,8+jLT $SHFT -N -K -O >> $PSFILE
NEQ=`wc ../sig_eq.tmp | awk '{print $1}'`
awk '{
    ot = substr($1,12,8)
    lo = $3
    la = $2
    dp = $4
    mg = $5
    if (NR<=8) {
        printf("%.1f  %.3f  %-11s\ %-9.2f%-9.2f %-10.2f%-7.1f\n"), 0,3.40-NR*0.32,ot,la,lo,dp,mg
    }
}END{
    if(NR>8){
        printf("%.1f  %.3f  :           :        :         :         :\n"), 0,3.40- 9*0.32
        printf("%.1f  %.3f  %d total earthquakes plotted\n"), 0,3.40-10*0.32,'$NEQ'
    }
}' ../sig_eq.tmp |\
    gmt pstext $PROJ $LIMS -F+f16,8+jLT $SHFT -N -K -O >> $PSFILE
# gmt psbasemap $PROJ $LIMS -Bxg0.2 -Byg0.2 $SHFT -K -O --MAP_GRID_PEN=0.25p,105 >> $PSFILE
# gmt psbasemap $PROJ $LIMS -Bxg1 -Byg1 $SHFT -K -O --MAP_GRID_PEN=1p >> $PSFILE



# Finalize map
echo "$SCRIPT [`print_time`]: finalizing PostScript file" | tee -a $LOG_FILE
gmt psxy -T -O >> $PSFILE



echo "$SCRIPT [`print_time`]: converting to PNG" | tee -a $LOG_FILE
gmt psconvert $PSFILE -Tg -A -I+m0.1i -E300



echo "$SCRIPT [`print_time`]: cleaning up" | tee -a $LOG_FILE
mv map.png ..
rm $PSFILE

cd ..

echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE
