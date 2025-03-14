#!/bin/bash
<<README
This script is only calling/sourcing getVar.sh which is potentially triggering 
the rewriting of .scripts.config

This script optionally takes one parameter for testing:
[$1] : any variable name from the central configuration file (.scripts.config)
This variable and its value will be displayed at the end of the script.

README

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/getVar.sh

intro $0

if [[ ! -z $1 ]]; then
	echo "${1}: ${!1}"
fi
