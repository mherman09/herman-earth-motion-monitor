#!/bin/bash

./download_waveforms.sh || exit 1
./process_waveforms.sh || exit 1
./plot_waveforms.sh || exit 1
./plot_map.sh || exit 1
open waveforms.png
open map.png
