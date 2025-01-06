#!/bin/bash
<<README
This script is only calling/sourcing getVar.sh which is potentially triggering 
the rewriting of .scripts.config

README

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/getVar.sh

intro $0
