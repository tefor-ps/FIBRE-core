#!/bin/bash
<< README
This script is creating a directory for each projectID at $PROJECTSDIR and links 
all folders of that project from $LABDATADIR into $RPOJECTSDIR

Parameters: 
This script does not need any parameters however the following parameters can be 
provided:  
   
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-f	force initial rewrite of index
			Overwrites pre-existing index. 

	-h	help
			Displays help.

README

usage() {
	printf "Usage: $(basename $0) [-f] [-h] [-p project]  
	
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-f	force initial rewrite of index
			Overwrites pre-existing index. 

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

#debug=2

intro $0

SEARCHSTRING=-

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
dbg2 "search string: $SEARCHSTRING"

# define local variables
INDEX=$INDEXDIR/$D.labdata.index		#TODO: implement common INDEX for alldata?
RAW=$INDEXDIR/$D.labdata.raw
TMP=$INDEXDIR/$D.pids.tmp
PIDs=$INDEXDIR/$D.labdata.pids
inputDir=$LABDATADIR/$IMPORTS
projectRegex=[A-Z0-9]*-[0-9]*-[A-Z]*

dbg "writing list of all raw data files in $inputDir to $INDEX" 
if [[ $(find $INDEX -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2> /dev/null) ]] && [[ $FORCEINDEX -eq 0 ]];  then
<<functionExplanation
The statement '$(find $INDEX -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2> /dev/null)' 
is TRUE, when $INDEX is younger than $permissibleAgeOfIndex .
$FORCEINDEX is TRUE when $1 is set 1 in the call of this script.
functionExplanation
	ls -l $INDEX  2>&1 |tee -a $LOG
	dbg "$INDEX is younger than $permissibleAgeOfIndex minutes. Skipping initial index generation." |tee -a $LOG
else
	find $inputDir -type f >$INDEX
	for stacktype in $(echo $STACKEXTENSION); do
		grep -e $stacktype $INDEX
	done >$RAW
fi

dbg "listing all projectIDs with raw data in $inputDir to $PIDs"
if [[ $(find $PIDs -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2> /dev/null) ]] && [[ $FORCEINDEX -eq 0 ]];  then
	ls -l $PIDs  2>&1 |tee -a $LOG
	warn "$PIDs is younger than $permissibleAgeOfIndex minutes. Skipping initial index generation." |tee -a $LOG
else
	while read i; do 
		basename "$i"|sed 's@_@\n@g'|while read frag; do 
			if [[ "$frag" == $projectRegex ]]; then 
				printf "$frag\n"; 
			fi
		 done 
	done <$RAW > $TMP
	cat $TMP |grep -e $SEARCHSTRING |sort -u > $PIDs
	rm $TMP
fi

dbg "finding all files for a given PID"
for pid in $(cat $PIDs); do
	dbg "sorting data for $pid"
	for img in $(grep $pid $INDEX); do # for each image (listed in INDEX), which is containing a PID in its filename
		dbg2 "$img"
		bn=$(basename $img) # extract basename of file
		msg $bn
		#dn=$(dirname $img) # extract path to file
		dn=$(echo $img |sed "s@$bn@@") # extract path to file 
		dbg2 "dn: $dn"
		dnbn=$(basename $dn) # extract name of the directory file is located in (without rest of the path)
		fdtog=0 # init fsdb-toggle zero
		for frag in $(echo $dn |tr "/" " "); do
			if [[ $(echo $frag |grep -c -e -fsdb) -gt 0 ]]; then
				fdtog=1
				op=$frag
			else
				if [[ $fdtog -eq 1 ]]; then
					op=${op}/$frag
				fi
			fi
		done
		dbg2 "op: $op"
		if [[ -f $img ]]; then
		#	fdtog=$(echo $img |grep -c -e $FSDB_EXT) 
			if [[ $fdtog -gt 0 ]]; then # if image exists AND its path contains the string typical for the fsdb
				dbg2 "A"
		#		opdn=$(dirname $op)
				#linkPath=$PROJECTSDIR/$pid/$dnbn
				linkPath=$PROJECTSDIR/$pid/$op
			else
				dbg2 "B"
				#linkPath=$PROJECTSDIR/$pid/
				linkPath=$PROJECTSDIR/$pid/$dnbn
			fi
			target=$img
			if [[ ! -d $linkPath ]]; then
				mkdir -p -v $linkPath 2>&1 >>$LOG # create dir in PROJECTSDIR
			fi
			dbg2 "sudo ln -f $target $linkPath"
			sudo ln -f $target $linkPath 2>/dev/null # link image into dir in PROJECTDIR
		fi
	done
	sudo chown -R ${ADMIN}:${LAB} $PROJECTSDIR/$pid
done

dbg "Done."
