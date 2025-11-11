#!/bin/bash
<<README
This script is only calling/sourcing getVar.sh which is potentially triggering 
the rewriting of .scripts.config

This script optionally takes one parameter for testing:
[$1] : any variable name from the central configuration file (.scripts.config)
This variable and its value will be displayed at the end of the script.

README

# find and source getVar.sh to set all global variables
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 || "$1" =~ "-" ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
	#source $thisDir/../scripts/core/getVar.sh
else 
	gv=$(find "$1" -type f -name getVar.sh)
	#source $1/core/getVar.sh
fi

if [[ -f "$gv" ]]; then
	source "$gv"
else
	echo "ERROR: Can't find getVar.sh"
	exit 555
fi

intro $(basename $0)

if [[ ! -z $1 ]]; then
	echo "${1}: ${!1}"
fi
