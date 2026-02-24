all: check download process plot_waveforms plot_map


.PHONY: check
check:
	./run_checks.sh

.PHONY: download
download: LOGS/download_waveforms.sh.log
LOGS/download_waveforms.sh.log: download_waveforms.sh param.dat
	./download_waveforms.sh


.PHONY: process
process: LOGS/process_waveforms.sh.log
LOGS/process_waveforms.sh.log: process_waveforms.sh param.dat LOGS/download_waveforms.sh.log
	./process_waveforms.sh


.PHONY: plot_waveforms
plot_waveforms: LOGS/plot_waveforms.sh.log
LOGS/plot_waveforms.sh.log: plot_waveforms.sh param.dat LOGS/download_waveforms.sh.log LOGS/process_waveforms.sh.log
	./plot_waveforms.sh


.PHONY: plot_map
plot_map: LOGS/plot_map.sh.log
LOGS/plot_map.sh.log: plot_map.sh param.dat LOGS/download_waveforms.sh.log LOGS/process_waveforms.sh.log
	./plot_map.sh