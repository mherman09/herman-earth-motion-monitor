#!/bin/bash


# set -e



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
#   DOWNLOAD SIGNIFICANT EARTHQUAKES
#####


# Time window saved in waveform download log file
echo "$SCRIPT [`print_time`]: extracting timing information from $WVFM_LOG_FILE" | tee -a $LOG_FILE
CALENDAR_TIME_START=`grep "CALENDAR_TIME_START=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END=`grep "CALENDAR_TIME_END=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_START_LOCAL=`grep "CALENDAR_TIME_START_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
CALENDAR_TIME_END_LOCAL=`grep "CALENDAR_TIME_END_LOCAL=" $WVFM_LOG_FILE | awk -F"=" '{print $2}'`
TIME_ZONE_LOCAL=`grep "TIME_ZONE_LOCAL=" $WVFM_LOG_FILE | awk -F= '{print $2}'`

EPOCH_TIME_END=$(grep "EPOCH_TIME_END=" $WVFM_LOG_FILE | awk -F"=" '{print $2}')
EPOCH_TIME_EQ_DOWNLOAD_START=$(echo $EPOCH_TIME_END | awk '{print $1-31536000}')

if [ "$DATE_VERSION" == "bsd-date" ]
then
    CALENDAR_TIME_EQ_DOWNLOAD_START=`date -u -r ${EPOCH_TIME_EQ_DOWNLOAD_START} "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_EQ_DOWNLOAD_START_LOCAL=`date -r "${EPOCH_TIME_EQ_DOWNLOAD_START}" "+%Y-%m-%dT%H:%M:%S"`
elif [ "$DATE_VERSION" == "gnu-date" ]
then
    CALENDAR_TIME_EQ_DOWNLOAD_START=`date -u -d "@${EPOCH_TIME_EQ_DOWNLOAD_START}" "+%Y-%m-%dT%H:%M:%S"`
    CALENDAR_TIME_EQ_DOWNLOAD_START_LOCAL=`date -d "@${EPOCH_TIME_EQ_DOWNLOAD_START}" "+%Y-%m-%dT%H:%M:%S"`
else
    echo "$SCRIPT [ERROR]: could not figure out version of date" 1>&2
    exit 1
fi

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
COMCAT_URL="https://earthquake.usgs.gov/fdsnws/event/1/query?starttime=${CALENDAR_TIME_EQ_DOWNLOAD_START}&endtime=${CALENDAR_TIME_END}&minsig=${MINSIG}&format=csv"
echo "$COMCAT_URL" >> $LOG_FILE
curl "$COMCAT_URL" > query.csv 2>> $LOG_FILE
COMCAT_URL="https://earthquake.usgs.gov/fdsnws/event/1/query?starttime=${CALENDAR_TIME_START}&endtime=${CALENDAR_TIME_END}&minsig=${MINSIG}&format=csv"
echo "$COMCAT_URL" >> $LOG_FILE
curl "$COMCAT_URL" > query_2.csv 2>> $LOG_FILE



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

    for F in query.csv query_2.csv
    do

        NSIG=$(wc $F | awk '{print $1}')
        echo "$SCRIPT [`print_time`]: plotting $NSIG significant earthquakes" | tee -a $LOG_FILE


        # Reverse order of events
        awk '{line[NR]=$0}END{for(i=NR;i>1;i--){print line[i]}}' $F > j
        mv j $F


        # Save significant earthquakes
        echo "$SCRIPT [`print_time`]: saving significant earthquakes in $(basename $F .csv).tmp" | tee -a $LOG_FILE
        awk -F, '{print $1,$2,$3,$4,$5}' $F > $(basename $F .csv).tmp

    done

fi






#####
#   PLOT GLOBE FRAMES
#####

# Do all the work in the ANIMATION directory
echo "$SCRIPT [`print_time`]: working in ANIMATION directory" | tee -a $LOG_FILE
test -d ANIMATION || mkdir ANIMATION
cd ANIMATION



# Remove globe/ directory if it exists
MOVIE_NAME=globe
test -d ${MOVIE_NAME} && rm -rf ${MOVIE_NAME}



# GMT settings
echo "$SCRIPT [`print_time`]: setting GMT parameters" | tee -a $LOG_FILE
gmt set MAP_FRAME_TYPE plain


# Save station list absolute path
STA_FILE_DIR=$(pwd)/../SAC
ls $STA_FILE_DIR/*.CI.*.sac > ${STA_FILE_DIR}/sta_file_list.tmp
ls $STA_FILE_DIR/*.IU.*.sac >> ${STA_FILE_DIR}/sta_file_list.tmp


# Save earthquake file absolute path
EQ_FILE=$(pwd)/../query.tmp
EQ_FILE_2=$(pwd)/../query_2.tmp





# Main animation script
echo "$SCRIPT [`print_time`]: creating main animation script main.sh" | tee -a $LOG_FILE

EQ_SCALE=0.0010

cat > main.bash << EOF


gmt begin


    # Set center longitude
    LON0=\$(echo \$MOVIE_COL0 | awk '{print -\$1}')


    # Coastline
    gmt coast -JG\${LON0}/0/11.2c -Rg -Di -G255 -S149/181/192 -A0/0/1 -X6.4c -Y0.25c


    # Basemap
    gmt basemap -Bxg30 -Byg30 --MAP_FRAME_PEN=0.5p --MAP_GRID_PEN=0.25p,105@70


    # Significant earthquakes
    if [ "$USGS_EQ_QUERY_ERROR" == "N" ]
    then
        gmt makecpt -T0/100/10 -Cplasma -I -D
        awk '{print '\$LON0',0,\$3,\$2}' ${EQ_FILE} |\\
            /home/mherman2/Research/Hdef/bin/lola2distaz -f stdin |\\
            awk '{print \$1}' |\\
            paste - ${EQ_FILE} |\\
            awk '{
                if (\$1/111.19<=93 && \$6>=5.0) {
                    if (\$6<7.0) {
                        p=1
                    } else if (\$6<8.0) {
                        p=2
                    } else {
                        p=3
                    }
                    if (\$1/111.19>90) {
                        t = (\$1/111.19-90)*33
                    } else {
                        t = 0
                    }
                    print "> -W"p"p"
                    print \$4,\$3,\$5,\$6*\$6*\$6*$EQ_SCALE,t
                }
            }' |\\
            gmt plot -Sci -W1p -C -N -t
        awk '{print '\$LON0',0,\$3,\$2}' ${EQ_FILE_2} |\\
            /home/mherman2/Research/Hdef/bin/lola2distaz -f stdin |\\
            awk '{print \$1}' |\\
            paste - ${EQ_FILE} |\\
            awk '{if (\$1/111.19<=93 && \$6>=5.0) {if(\$6<7.0){p=1}else if(\$6<8.0){p=2}else{p=3};print "> -W"p"p,green"; print \$4,\$3,\$5,\$6*\$6*\$6*$EQ_SCALE}}' |\\
            gmt plot -Sci -W1p -C -N
    fi


    # Seismic stations
    for TRACE in \$(cat ${STA_FILE_DIR}/sta_file_list.tmp)
    do

        # Get directory name and ASCII seismogram file name
        DIR=\$(dirname \$TRACE)
        ASCII_FILE=\$(basename \$TRACE .sac).dat

        # Plot stations
        KSTNM=\$(/home/mherman2/Research/PROGRAMS.330/bin/saclhdr -KSTNM \$TRACE)
        STLO=\$(/home/mherman2/Research/PROGRAMS.330/bin/saclhdr -STLO \$TRACE)
        STLA=\$(/home/mherman2/Research/PROGRAMS.330/bin/saclhdr -STLA \$TRACE)
        DIST=\$(/home/mherman2/Research/Hdef/bin/lola2distaz -c \$LON0 0 \$STLO \$STLA |\\
            awk '{print \$1/111.19}')
        PLOT=\$(echo \$DIST | awk '{if(\$1<=93){print "Y"}else{print "N"}}')
        if [ \$PLOT == "Y" ]
        then
            echo \$STLO \$STLA | gmt plot -Si0.1i -W1p -Gred -N
            echo \$STLO \$STLA \$KSTNM | gmt text -F+f7,1+jCB -D0/0.07i -N
        fi
    done


    # Magnitude legend
    X0=14.0
    Y0=2.5
    echo \$X0 8.00 Magnitude | gmt pstext -JX1c -R0/1/0/1 -F+f20,2+jCT -N -D0/\${Y0}
    echo 6.10 9.0 > mag_legend.tmp
    echo 4.30 8.0 >> mag_legend.tmp
    echo 3.00 7.0 >> mag_legend.tmp
    echo 2.10 6.0 >> mag_legend.tmp
    echo 1.50 5.0 >> mag_legend.tmp
    awk '{print '\$X0', \$1+'\$Y0', \$2^3*$EQ_SCALE}' mag_legend.tmp | gmt plot -W1p -G235 -Sci -N
    awk '{print '\$X0'+\$2^3*$EQ_SCALE/2*2.54, \$1+'\$Y0', 9+(\$2-4)*2.0, \$2}' mag_legend.tmp |\\
        gmt text -F+f+jLM -D0.05i/0 -N


    # Depth Legend
    echo -2.90 10.5 Depth \(km\) |\\
        gmt text -F+f20,2+jCT -N
    gmt colorbar -Dx-3.0/2.5+w-6.8/0.60+ef+ma -C --FONT_ANNOT=14


    # Seismometer legend
    echo \$X0 2.60 Seismometers | gmt pstext -JX1c -R0/1/0/1 -F+f20,2+jCT -N
    echo \$X0 1.50 Station | gmt text -F+f7,1+jCB -D0/0.07i -N
    echo \$X0 1.50 | gmt plot -Si0.1i -W1p -Gred -N


gmt end

EOF



# Run gmt movie
echo "$SCRIPT [`print_time`]: running gmt movie to generate animation" | tee -a $LOG_FILE

LON_START=0
LON_END=360
DLON=0.5
DLON=90
LON_END=$(echo $LON_END $DLON | awk '{print $1-$2*2}')

FPS=24
FPS=12

CANVAS_WID=24c
CANVAS_HGT=12.5c
CANVAS_DPU=80

MASTER_FRAME=3

# -Zs removes all directories, temporary scripts, etc.
# -L adds labels
# -Pb+Pblack+pwhite+a adds a progress circle
# -x8 limits number of cores

gmt movie main.bash \
    -N${MOVIE_NAME} \
    -C${CANVAS_WID}x${CANVAS_HGT}x${CANVAS_DPU} \
    -T${LON_START}/${LON_END}/${DLON} \
    -M${MASTER_FRAME},png \
    -Fgif+l \
    -Zs \
    -Gwhite \
    -D${FPS} \
    -Ls"Earthquakes Around the World (Past Year)"+jTC+f24,0 \
    -Ls"$CALENDAR_TIME_EQ_DOWNLOAD_START @%2%@:8:to@::@%% $CALENDAR_TIME_END \(UTC\)"+jBL+f9,2 \
    -Ls"$CALENDAR_TIME_EQ_DOWNLOAD_START_LOCAL @%2%@:8:to@::@%% $CALENDAR_TIME_END_LOCAL \($TIME_ZONE_LOCAL\)"+jBR+f9,2 \
    -Vi



echo "$SCRIPT [`print_time`]: cleaning up" | tee -a $LOG_FILE

echo "$SCRIPT [`print_time`]: finished" | tee -a $LOG_FILE

cd ..
# pkill vlc
# vlc ANIMATION/${MOVIE_NAME}.mp4 &
