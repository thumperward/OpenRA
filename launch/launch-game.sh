#! /bin/bash
set -euo pipefail

ENGINEDIR=$(dirname "$0")/../packaging/linux/

# Prompt for a mod to launch if one is not already specified
MODARG="${1:-}"
if [ -z "${MODARG:-}" ]; then
	if command -v zenity >/dev/null; then
		TITLE=$(
			zenity \
				--list --hide-header --title='Launch OpenRA' --text 'Select game mod:' \
				--column 'Game mod' 'Red Alert' 'Tiberian Dawn' 'Dune 2000' 'Tiberian Sun' || echo "cancel"
		)
		if [ "$TITLE" = "Tiberian Dawn" ]; then
			MODARG='cnc'
		elif [ "$TITLE" = "Dune 2000" ]; then
			MODARG='d2k'
		elif [ "$TITLE" = "Tiberian Sun" ]; then
			MODARG='ts'
		elif [ "$TITLE" = "Red Alert" ]; then
			MODARG='ra'
		else
			exit 0
		fi
	else
		echo "Please provide the GAMEMOD=\$MOD argument (possible \$MOD values: ra, cnc, d2k, ts)"
		exit 1
	fi
fi

# Launch the engine with the appropriate arguments
"${ENGINEDIR}/${MODARG}/build/.appdir/AppRun" && rc=0 || rc=$?

# Show a crash dialog if something went wrong
if [ "${rc}" != 0 ] && [ "${rc}" != 1 ]; then
	if [ "$(uname -s)" = "Darwin" ]; then
		LOGS="${HOME}/Library/Application Support/OpenRA/Logs/"
	else
		LOGS="${XDG_CONFIG_HOME:-${HOME}/.config}/openra/Logs"
		if [ ! -d "${LOGS}" ] && [ -d "${HOME}/.openra/Logs" ]; then
			LOGS="${HOME}/.openra/Logs"
		fi
	fi

	if [ -d Support/Logs ]; then
		LOGS="${PWD}/Support/Logs"
	fi
	ERROR_MESSAGE=$(printf "%s has encountered a fatal error.\nPlease refer to the crash logs and FAQ for more information.\n\nLog files are located in %s\nThe FAQ is available at http://wiki.openra.net/FAQ" "OpenRA" "${LOGS}")
	if command -v zenity >/dev/null; then
		zenity --no-wrap --error --title "OpenRA" --no-markup --text "${ERROR_MESSAGE}" 2>/dev/null || :
	elif command -v kdialog >/dev/null; then
		kdialog --title "OpenRA" --error "${ERROR_MESSAGE}" || :
	else
		echo "${ERROR_MESSAGE}"
	fi
	exit 1
fi
