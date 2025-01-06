#!/bin/bash
<< README
This script is removing the lock files - which were generated during the 
secondary data generation (runner.sh). 

By default only lock files older than 1 day are removed.

Parameters: 
This script does not need any parameters however the following parameters can be 
provided:  
   
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-f	force removal of all lock files
			Remove also the lock files of today. This is made for immediate 
			re-running a batch e.g., during tewsting or debugging.
			This function can also be achieved by passing the keyword "today" 
			as first (and only) parameter to this script.

	-h	help
			Displays help.

underlying conept:
- find lock-files, which need to be removed
- remove them
- log all removals into LOG

README
#fsdb-rev-date: 241012

usage() {
	printf "Usage: $(basename $0) [-f] [-h] [-p project]  
	
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-f	force removal of all lock files
			Remove also the lock files of today. This is made for immediate 
			re-running a batch e.g., during tewsting or debugging.

	-h	help
			Displays this help.


" 1>&2;
	exit 1;
}

guardian() {
<<functionExplanation
The guardian is avoiding the assignment of options (e.g. -p) as arguments by
excluding everything, which starts with a hyphen from the pool of possible
arguments.
functionExplanation

	if [ "$(echo ${1:0:1})" == "-" ]; then
		warn "Guardian says: Invalid argument: $1" >&2
		usage
	fi
}


# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0

debug=3

FORCEINDEX=0

# get parameters/options passed at call of this script
while getopts ":p:fh" opt; do
	case $opt in
		p)
			guardian $OPTARG
			dbg2 "Option -p was triggered, argument: $OPTARG" 
			SEARCHSTRING=$OPTARG
			;;
		f)
			guardian $OPTARG
			dbg2 "Option -f was triggered, this will force index generation"
			FORCEINDEX=1
			;;
		h)
			usage
			;;
		\?)
			error "Invalid option: -$OPTARG" 
			exit 1
			;;
		:)
			error "Option -$OPTARG requires an argument." 
			exit 1
			;;
	esac
done
shift $((OPTIND-1))
dbg3 "search string: $SEARCHSTRING"

# define name and location of temporary list of lock files
tmplist=$WORKDIR/lockfiles

if [[ "$1" == "today" || $FORCINDEX -eq 1 ]]; then
# remove all lock files 
	for i in $(find $LABDATADIR/imports/ -type f -name "*$SEARCHSTRING*.lock"); do
		dbg $i
		if [[ $debug -gt 2 ]];then
			rm -fv $i 2>&1 |tee -a $LOG
		else
			rm -fv $i 2>&1 >> $LOG
		fi
	done
else
# remove all lock files older than 24h
	for i in $(find $LABDATADIR/imports/ -type f -mtime +1 -name "*$SEARCHSTRING*.lock"); do
		dbg $i
		if [[ $debug -gt 2 ]];then
			rm -fv $i 2>&1 |tee -a $LOG
		else
			rm -fv $i 2>&1 >> $LOG
		fi
	done
fi
