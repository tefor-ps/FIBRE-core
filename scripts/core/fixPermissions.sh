#!/bin/bash
<<README
For making sure, that the files are accessible and protected as intended, this
script is (re-)setting the permissions on the fsdb file system and the contained
files.

This script is part of $CLEANIMPORTS

This scripr accepts one optional parameter: 
[$1] = path to the directory which permissions need to be fixed

underlying concept:
- each original data set has two 'pointers', which earlier were gernerated using 'ln'. 
-- one in $STORAGEDIR/$IMPORTS, the other in $LABDATADIR/$IMPORTS, at the corresponding location.
- data at $LABDATADIR/$IMPORTS are user-writeable (770) and by this endangered by destruction/deletion.
- $STORAGEDIR/$IMPORTS and the data within is read-only and inaccessible for standard users.
- if original data is accidentially removed from $LABDATADIR/$IMPORTS, this script reconstitutes it from $STORAGEDIR/$IMPORTS. 

mode of function:
- set permissions for $LABDATADIR/$IMPORTS/ to 770
- set permissions for $INDEXDIR/ to 770
- set permissions for $STORAGEDIR/$IMPORTS/ to 750
README
#fsdb-rev-date: 260123

usage() {
	printf "Usage: $(basename $0) [-f] [-h] [-d dir] [-p project]  
	
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-d	directory
			This is the absolute path to the directory, which is supposed to be indexed.
				
	-f	force removal of all lock files
			Remove also the lock files of today. This is made for immediate 
			re-running a batch e.g., during testing or debugging.

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

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

# set default values 
DEFAULTINDIR=$LABDATADIR/$IMPORTS/
INDIR=$DEFAULTINDIR
SEARCHSTRING="."
FORCEINDEX=0
PSTRING="" # $PSTRING prefixes '-p ' to the $SEARCHSTRING, so it can be used directly in downstream scripts
FSTRING="" # $FSTRING is '-f' when $FORCEINDEX is 1, so it can be used directly in downstream scripts
DSTRING="" # $DSTRING prefixes '-d ' to the provided directory, so it can be used directly in downstream scripts

# get options passed at call of this script
while getopts ":p:d:fh" opt; do
	case $opt in
		p)
			guardian $OPTARG
			dbg2 "Option -p was triggered, argument: $OPTARG" 
			SEARCHSTRING=$OPTARG
			PSTRING="-p $SEARCHSTRING"
			;;
		d)
			guardian $OPTARG
			dbg2 "Option -d was triggered, argument: $OPTARG"
			if [[ -d $OPTARG ]]; then
				INDIR=$(realpath $OPTARG)
				DSTRING="-d $INDIR"
			else
				error "$OPTARG is not a directory."
				usage
			fi
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
dbg2 "parameters: $PSTRING $FSTRING $DSTRING"
dbg3 "search string: $SEARCHSTRING"

# satisfy prerequisits
which setfacl >/dev/null
if [[ $? -eq 1 ]]; then
	sudo apt -y install acl
fi

#============================
# FUNCTION DEFINITIONS
#============================

function fixPerms() {
	if [[ "$4" == "recursive" ]];then 
		dbg2 "fixing permissions recursively for ${dir} : $3"
		if [[ $debug -gt 2 ]]; then
			sudo mkdir -vp $dir |tee -a $LOG 2>&1
			sudo chown -vR $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -vR $3 $dir |tee -a $LOG 2>&1
		else 
			sudo mkdir -p $dir |tee -a $LOG 2>&1
			sudo chown -R $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -R $3 $dir |tee -a $LOG 2>&1
		fi
	else
		dbg2 "fixing permissions for $dir"
		if [[ $debug -gt 2 ]]; then
			sudo mkdir -vp $dir |tee -a $LOG 2>&1
			sudo chown -v $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -v $3 $dir |tee -a $LOG 2>&1
		else 
			sudo mkdir -p $dir |tee -a $LOG 2>&1
			sudo chown $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod $3 $dir |tee -a $LOG 2>&1
		fi
	fi
}

#============================
# FUNCTION CALLS
#============================

if [[ "$INDIR" == "$DEFAULTINDIR" ]]; then
	# set ownership and permissions on administrative folders (ADMIN-level).
	for dir in $BUPROOT $DUMPDIR $ATTICDIR; do
		fixPerms $ADMIN $ADMIN 700 recursive
	done
	
	# set ownership and permissions on inaccessible folders.
	#	for dir in $DATAROOT $LABDIR; do
	#		fixPerms $ADMIN $GROUP 750
	#	done
	for dir in $INDEXDIR $ARCHIVEDIR; do
	#for dir in $INDEXDIR ; do
		fixPerms $ADMIN $GROUP 750 recursive
	done
	
	
	# set ownership and permissions recursively on accessible directory (GROUP-level)
	for dir in $LABDATADIR/$IMPORTS $EXCHANGEDIR; do
		fixPerms $GROUP $GROUP 770 recursive
	done
	
	# set ownership and permissions recursively on accessible directory (ORGANISATION-level
	for dir in $EXPORTDIR ; do
		fixPerms $GROUP $CONSORTIUM 770 recursive
	done
	
	# reset ownership and permissions on inaccessible folder.
	# this overwrites the permissions of the raw-data, which are the only data sets
	# in both locations to 750, which protects them from accidential deletion.
	for dir in $STORAGEDIR/$IMPORTS; do
		fixPerms $ADMIN $GROUP 750 recursive
		sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
	done
	
	## nice little 'echo's. mainly for interactive usage.
	#tree -pug -L 1 $LABDATADIR/$IMPORTS/
	#tree -pug $DATAROOT
	#tree -pug $WORKDIR
else
	#dir=$(realpath $1)
	dir=$INDIR
	dbg2 "dir: $dir"
	case "$dir" in
		"$LABDATADIR/$IMPORTS"*)
dbg2 "A: $LABDATADIR/$IMPORTS"
			fixPerms $GROUP $GROUP 770 recursive
			# now set the permissions of the raw data back to 750 - to prevent their accidential deletion.
			dir=$(echo $dir |sed "s@$LABDATADIR@$STORAGEDIR@")
			fixPerms $ADMIN $GROUP 750 recursive
			sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
			;;
		"$EXCHANGEDIR"*)
dbg2 "B: $EXCHANGEDIR"
			fixPerms $GROUP $GROUP 770 recursive
			;;
		"$INDEXDIR"*)
dbg2 "C: $INDEXDIR"
			fixPerms $ADMIN $GROUP 750 recursive
			;;
		"$ARCHIVEDIR"*)
dbg2 "D: $ARCHIVEDIR"
			fixPerms $ADMIN $GROUP 750 recursive
			;;
		"$BUPROOT"*)
dbg2 "E: $BUPROOT"
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$DUMPDIR"*)
dbg2 "F: $DUMPDIR"
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$ADMINDIR"*)
dbg2 "G: $ADMINDIR"
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$EXPORTDIR"*)
dbg2 "H: $EXPORTDIR"
			fixPerms $GROUP $CONSORTIUM 770 recursive
			;;
		"$STORAGEDIR/$IMPORTS"*)
dbg2 "I: $STORAGEDIR/$IMPORTS"
			fixPerms $ADMIN $GROUP 750 recursive
			sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
			;;
		*)
dbg2 "J: $dir"
			fixPerms $ADMIN $GROUP 770 recursive
			dbg "$dir"
			#echo "invalid path, can't fix permission"
			;;
	esac
	dbg "$(ls -l $dir)"
fi