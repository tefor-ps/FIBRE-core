#!/bin/bash
<<README
This script is only calling/sourcing getVar.sh which is potentially triggering 
the rewriting of .scripts.config

This script optionally takes one parameter for testing:
[$1] : any variable name from the central configuration file (.scripts.config)
This variable and its value will be displayed at the end of the script.

README

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# get variables of fsdb from getVar.sh
if ! source getVar; then
	dir=$thisDir 
	for _ in $(seq 1 4); do
		GV=$(find "$dir" -name "getVar.sh" -print -quit)
		if [[ -f $GV ]]; then 
			source "${GV}"
			break 
		else
			dir="$(dirname "$dir")"
		fi
	done
	if [[ ! -f "${GV}" ]]; then
		echo "ERROR: Can't find getVar.sh"
		exit 555
	fi
fi
intro $(basename $0)

debug=2

if [[ ! -z $1 ]]; then
	intro "${1}: ${!1}"
fi
