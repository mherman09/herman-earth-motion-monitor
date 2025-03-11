#!/bin/bash

echo "****************************************************************************************************"

echo starting $0 at `date`

echo checking for executables
for EXEC in curl \
            gsac \
            sac \
            gmt \
            lola2distaz
do
    which $EXEC 1> /dev/null || { echo $0: could not find $EXEC; echo exiting; exit 1; }
done

echo downloading waveforms
./download_waveforms.sh ||\
    { echo download_waveforms.sh exited with error; exit 1; }

echo processing waveforms
./process_waveforms.sh ||\
    { echo process_waveforms.sh exited with error; exit 1; }

echo plotting waveforms
./plot_waveforms.sh ||\
    { echo plot_waveforms.sh exited with error; exit 1; }

echo plotting map
./plot_map.sh ||\
    { echo plot_map.sh exited with error; exit 1; }

echo finished $0 at `date`

echo "****************************************************************************************************"
echo
echo