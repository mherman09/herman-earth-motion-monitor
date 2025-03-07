#!/bin/bash

# Following MECH.NZ/PROTO.CWB/CWBDOEVT (Robert Herrmann's regional moment tensor tools)

#####
#   INITIALIZE LOG FILE
#####
PWD=`pwd`
LOG_FILE=${PWD}/$0.log
echo starting $0 > $LOG_FILE
echo Current time in local time zone: `date "+%Y-%m-%dT%H:%M:%S"` >> $LOG_FILE



#####
#   PROCESS WAVEFORMS
#####

# Get bandpass filter corner frequencies from param.dat
HP_FILTER_CORNER_FREQ=`grep "HP_FILTER_CORNER_FREQ=" param.dat | awk -F"=" '{print $2}'`
LP_FILTER_CORNER_FREQ=`grep "LP_FILTER_CORNER_FREQ=" param.dat | awk -F"=" '{print $2}'`
echo HP_FILTER_CORNER_FREQ=$HP_FILTER_CORNER_FREQ >> $LOG_FILE
echo LP_FILTER_CORNER_FREQ=$LP_FILTER_CORNER_FREQ >> $LOG_FILE


# Work in the waveform directory created by download_waveforms.sh only
test -d SAC && cd SAC || exit 1


# Process each trace
for TRACE in *.SAC
do
    echo processing trace $TRACE >> $LOG_FILE

    # Extract station and time series information from SAC file header
    KSTNM=`saclhdr -KSTNM $TRACE`                  # station name
    KCMPNM=`saclhdr -KCMPNM $TRACE`                # component
    DELTA=`saclhdr -DELTA $TRACE`                  # time increment (s)
    FHH=`echo $DELTA | awk '{print 0.50/$1}' `     # Nyquist frequency
    FHL=`echo $DELTA | awk '{print 0.25/$1}' `     # half Nyquist frequency (to build decon filter)
    KNETWK=`saclhdr -KNETWK $TRACE`                # network
    if [ ${KNETWK} == "-12345" ]
    then
        NET=""
    else
        NET=${KNETWK}
    fi
    KHOLE=`saclhdr -KHOLE $TRACE`                  # location
    if [ -z ${KHOLE} ]
    then
        LOC="--"
    else
        if [ ${KHOLE} == "-12345" ]
        then
            LOC="--"
        else
            LOC=${KHOLE}
        fi
    fi

    # deconvolve to ground velocity in meters per second and bandpass filter using parameters from param.dat
    HPF=`echo $HP_FILTER_CORNER_FREQ 0.003 | awk '{if($1<$2){print $2}else{print $1}}'`
    LPF=`echo $LP_FILTER_CORNER_FREQ $FHL  | awk '{if($1>$2){print $2}else{print $1}}'`
gsac >> $LOG_FILE << EOF
r $TRACE
rtr
transfer from polezero subtype PZRESP.${KNETWK}.${KSTNM}.${LOC}.${KCMPNM}  TO VEL FREQLIMITS 0.002 0.003 ${FHL} ${FHH}
hp c $HPF n 3
lp c $LPF n 3
taper hanning w 0.02
w ${KSTNM}.${KCMPNM}.${NET}.${LOC}.sac
quit
EOF

    # write sac file to text file
sac << EOF >> $LOG_FILE
r ${KSTNM}.${KCMPNM}.${NET}.${LOC}.sac
w ALPHA ${KSTNM}.${KCMPNM}.${NET}.${LOC}.dat
quit
EOF


done



echo finished $0 >> $LOG_FILE

