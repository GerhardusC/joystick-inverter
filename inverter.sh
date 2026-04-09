#!/bin/bash

# -----------------------------------
# This is part of resetting the terminal is taken from ES-logo-changer.
CURRENT_TTY="/dev/tty1"
sudo chmod 666 $CURRENT_TTY
reset
printf "\e[?25l" > $CURRENT_TTY
dialog --clear
# -----------------------------------

# -----------------------------------
# This part is also kind of adapted from ES-logo-changer.
cleanup() {
	printf "\033c" > $CURRENT_TTY
	if [[ ! -z $(pgrep -f gptokeyb) ]]; then
		pgrep -f gptokeyb | sudo xargs kill -9
	fi
	exit 0
}

init_session() {
	# Workaround to get user input into tui
	sudo chmod 666 /dev/uinput
	export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
	if [[ ! -z $(pgrep -f gptokeyb) ]]; then
		pgrep -f gptokeyb | sudo xargs kill -9
	fi
	/opt/inttools/gptokeyb -1 "inverter" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
}
# -----------------------------------

init_session

# 2. Run Perl script
sudo perl /roms/tools/inverter/inverter.pl
cleanup

# Cleanup is handled automatically by the trap above
