#!/bin/bash
<<README
This script is a simple wrapper for other scripts, which are cleaning up the fsdb.

This cleaning mechanism is broken into multiple scripts to give the systems
administrator the opportunity of running them also separately through individual
cron-jobs or manually.

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

README
#fsdb-rev-date: 241012

#TODO: makeProjectLinks is not creating subdirectories

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

#debug=2

FORCEINDEX=0
PSTRING=""

# get parameters/options passed at call of this script
while getopts ":p:fh" opt; do
	case $opt in
		p)
			guardian $OPTARG
			dbg2 "Option -p was triggered, argument: $OPTARG" 
			SEARCHSTRING=$OPTARG
			PSTRING="-p $SEARCHSTRING"
			;;
		f)
			guardian $OPTARG
			dbg2 "Option -f was triggered, this will force index generation"
			FORCEINDEX=1
			FSTRING="-f"
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
dbg2 "parameters: $PSTRING $FSTRING"
dbg3 "search string: $SEARCHSTRING"

# update index - this call gives the user to force the ceartion of a new index before anything else 
dbg "forcing new index generation"
dbg2 "$MAKEINDEX $PSTRING $FSTRING"
if [[ $debug -gt 0 ]]; then
	bash $MAKEINDEX $PSTRING $FSTRING 2>&1 |tee -a $LOG
else
	bash $MAKEINDEX $PSTRING $FSTRING 2>&1 >> $LOG
fi

# synchronize the data in the hidden storage location (STORAGESDIR) with the accessible one (LABDATADIR)
dbg "make sure, that the images are at the right location in $STORAGEDIR and $LABDATADIR"
dbg2 $CLEANIMPORTS
if [[ $debug -gt 0 ]]; then
	bash $CLEANIMPORTS 2>&1 |tee -a $LOG
else
	bash $CLEANIMPORTS 2>&1 >> $LOG
fi
# this is also calling $FIXPERMISSIONS

# re-sort data in LABDATADIR/IMPORTS into project based directories in PROJECTSDIR
dbg "generate project directories"
dbg2 "$MAKEPROJECTDIRS $PSTRING $FSTRING"
if [[ $debug -gt 0 ]]; then
	bash $MAKEPROJECTDIRS $PSTRING $FSTRING 2>&1 |tee -a $LOG
else
	bash $MAKEPROJECTDIRS $PSTRING $FSTRING 2>&1 >> $LOG
fi

# remove all data older than 30 days from the directory EXCHANGEDIR
dbg "clean exchange folder"
dbg2 $CLEANEXCHANGE
if [[ $debug -gt 0 ]]; then
	bash $CLEANEXCHANGE 2>&1 |tee -a $LOG
else
	bash $CLEANEXCHANGE 2>&1 >> $LOG
fi

# remove all data older than 30 days from the directory /tmp/
dbg "clean the /tmp directory from outdated files"
dbg2 $CLEANTMP
if [[ $debug -gt 0 ]]; then
	bash $CLEANTMP 2>&1 |tee -a $LOG
else
	bash $CLEANTMP 2>&1 >> $LOG
fi

# remove all data older than 180 days from the directory DUMPDIR
dbg "remove data older than 180 days from dump"
dbg2 $CLEANDUMP
if [[ $debug -gt 0 ]]; then
	bash $CLEANDUMP 2>&1 |tee -a $LOG
else
	bash $CLEANDUMP 2>&1 >> $LOG
fi

# generate a new index. Here we always force the index generation, because 
# 1) an index for sure already exists 
# 2) newly generated data need to be indexed.
dbg "generate new index"
if [[ $debug -gt 0 ]]; then
	bash $MAKEINDEX -f $PSTRING 2>&1 |tee -a $LOG
else
	bash $MAKEINDEX -f $PSTRING 2>&1 >> $LOG
fi

# remove 'lifext'-files 
dbg "remove unwanted lifext files"
dbg2 $CLEANLIFEXT
if [[ $debug -gt 0 ]]; then
	bash $CLEANLIFEXT 2>&1 |tee -a $LOG
else
	bash $CLEANLIFEXT 2>&1 >> $LOG
fi

# remove old lock files
dbg "remove the lock files of yesterday"
dbg2 "$CLEANLOCKS $FSTRING $PSTRING"
if [[ $debug -gt 0 ]]; then
	bash $CLEANLOCKS $FSTRING $PSTRING 2>&1 |tee -a $LOG
else
	bash $CLEANLOCKS $FSTRING $PSTRING 2>&1 >> $LOG
fi


