all: download process plot_waveforms



# Run checks for installed programs
.PHONY: check
check: LOGS/run_checks.sh.log
LOGS/run_checks.sh.log: run_checks.sh
	./run_checks.sh



# Generate parameter file from template
.PHONY: param
param: param.dat
param.dat: param.dat.tmpl
	cp param.dat.tmpl param.dat



# Download waveforms from SAGE
.PHONY: download
download: LOGS/download_waveforms.sh.log
LOGS/download_waveforms.sh.log: download_waveforms.sh param.dat
	./run_checks.sh > /dev/null
	./download_waveforms.sh


# Process waveforms for plotting
.PHONY: process
process: LOGS/process_waveforms.sh.log
LOGS/process_waveforms.sh.log: process_waveforms.sh param.dat LOGS/download_waveforms.sh.log
	./run_checks.sh > /dev/null
	./process_waveforms.sh


# Plot waveforms
.PHONY: plot_waveforms
plot_waveforms: LOGS/plot_waveforms.sh.log
LOGS/plot_waveforms.sh.log: plot_waveforms.sh param.dat LOGS/download_waveforms.sh.log LOGS/process_waveforms.sh.log
	./run_checks.sh > /dev/null
	./plot_waveforms.sh


# Plot map of earthquakes
.PHONY: plot_map
plot_map: LOGS/plot_map.sh.log
LOGS/plot_map.sh.log: plot_map.sh param.dat LOGS/download_waveforms.sh.log LOGS/process_waveforms.sh.log
	./run_checks.sh > /dev/null
	./plot_map.sh


# Plot animation of spinning globe with earthquakes
.PHONY: animation
animation: LOGS/plot_globe_animation.sh.log
LOGS/plot_globe_animation.sh.log: plot_globe_animation.sh param.dat
	./run_checks.sh > /dev/null
	./plot_globe_animation.sh



# CLEAN UP!!!!
.PHONY: clean
clean:
	-rm *.tmp
	-rm *.png
	-rm *.pdf