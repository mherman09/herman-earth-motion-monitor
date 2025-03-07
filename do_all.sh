#!/bin/bash

echo "****************************************************************************************************"
echo starting $0 at `date`
echo downloading waveforms
./download_waveforms.sh || exit 1
echo processing waveforms
./process_waveforms.sh || exit 1
echo plotting waveforms
./plot_waveforms.sh || exit 1
echo plotting map
./plot_map.sh || exit 1
echo finished $0 at `date`
echo "****************************************************************************************************"
echo
echo