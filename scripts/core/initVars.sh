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

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

if [[ ! -z $1 ]]; then
	echo "${1}: ${!1}"
fi
