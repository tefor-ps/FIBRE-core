#!/bin/bash
<<README
This script removes the Leica lifext-files, which are generated automatically by the LASX software.

README

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0

#debug=0

for dir in $STORAGEDIR $LABDATADIR; do 
	for i in $(find $dir -type f -name "*.lifext"); do
		rm -f $i
	done
done