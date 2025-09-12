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
HEMM consists of several shell scripts. The basic processing scripts can be run individually,
they can be run in a batch with `do_all.sh`, or run repeatedly with `hemm.sh`. Most users will
want to use `hemm.sh` or `do_all.sh` unless they are debugging issues with the individual
processing scripts. 
- `hemm.sh`: runs `do_all.sh` repeatedly, with constant delay between repeats
- `do_all.sh`: runs all processing scripts
- `download_waveforms.sh`: builds query and downloads waveforms from SAGE
- `process_waveforms.sh`: filters and cuts waveforms
- `plot_waveforms.sh`: plots waveform time series
- `plot_map.sh`: plots map of earthquakes (if any)
