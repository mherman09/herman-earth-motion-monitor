# Herman Earth Motion Monitor (HEMM)

This program is intended to emulate the appearance of Charles Ammon's Earth Motion Monitor.
Instead of making this a polished macOS or iOS app, this version uses open-source software
packages, including SAC (Seismic Analysis Code), GSAC (General Seismic Analysis Code), and
GMT (Generic Mapping Tools).


## Requirements

The following packages must be installed and in the user's path to run HEMM:
- Curl
- [GSAC](https://rbherrmann.github.io/ComputerProgramsSeismology/index.html): seismic trace manipulation
- [SAC](https://ds.iris.edu/ds/nodes/dmc/software/downloads/sac): general purpose time series analysis
- [GMT](https://www.generic-mapping-tools.org): Earth, ocean, planetary science toolbox
- [Hdef](https://github.com/mherman09/hdef): Earth deformation calculation and plotting


## Running HEMM

HEMM consists of several shell scripts and a Makefile. The scripts can be run individually,
they can be run in a batch with `make all`, or run on repeat with `hemm.sh`. Most users will
want to use `hemm.sh` or `make all` unless they are debugging issues with the individual
processing scripts. 
- `hemm.sh`: runs `make all` repeatedly, with a delay (default: 200 s)
- `download_waveforms.sh`: builds query and downloads waveforms from IRIS/SAGE
- `process_waveforms.sh`: filters, cuts, and decimates waveforms using GSAC/SAC
- `plot_waveforms.sh`: plots waveform time series using GMT
- `plot_map.sh`: plots map of earthquakes using GMT

### Control File
The parameters for HEMM visualization are defined in the file `param.dat`.
This file contains the following variables:
- Data channels to download
- Start time of records (default leaves this out, and downloads to present)
- Duration of records
- Bandpass corner frequencies
- Minimum significance of earthquakes to plot
