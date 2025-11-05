#!/bin/bash
<<README
This script is listing the content of $LABDATADIR and $STORAGEDIR and extracts 
todo-lists for the secondary data generation.


parameters: 
This script does not need any parameters. 
However, the following parameters can be provided:  
   
	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
				
	-d	directory
			This is the absolute path to the directory, which is supposed to be indexed.

	-f	force index generation
			Setting this parameter forces the index-generation, even if the pre-existing 
			index is younger that the age-limit.

	-h	help
			Displays help.

underlying concepts:
- because searching the file system (especially in large data collections) for 
every step would be excruiatingly slow, the fsdb is running this indexing system
(at least once per day by cron-job or on demand, if today's indices do not exist, yet).
- queries (grep) on the resulting index-files are significantly faster, than the
alternative (find).

Since many of the specimens in question are too big for acquisition in a single 
field-of-view, they are imaged in tile-scan. The results are saved in two data 
sets: 'tiles' (rawest form) and 'merged' (tiles stitched together into one file).
This convention was movitated by the output of Lieca microscopes.
High resolution images with only one tile may be stored with the suffix 'stack' 
and are treated like merged images.

README

#fsdb-rev-date: 251105

#TODO: implement search on $PROJECTSDIR ?

#============================
# function definitions
#============================
usage() {
	printf "Usage: $(basename $0) [-p project] [-o order] [-h] absolute-paths

	-p	project/pattern
			This is a limiting string, which is included in the 'find' command.
			Setting this will limit the population of files to files, whose filenames 
			include this string.
			
	-d	directory
			This is the absolute path to the directory, which is supposed to be indexed.
				
	-f	force index generation
			Setting this parameter forces the index-generation, even if the pre-existing 
			index is younger that the age-limit.

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


getTOG() {
# DEPRECATED?
<<functionExplanation
This function reads the toggles from $CONFIG and returns the corresponding (concatenated) suffix for the secondary data.
Possible inputs are
PP for _PPTOG for the pre-processing steps (color map correction, automatic cropping) 
IP for _IPTOG for the actual image processing steps
IA for _IATOG for the image annotation steps (scalebars, contrast settings)

These GLOBAL toogles overrule the others, meaning if they are set 0, none of the 
subordiante steps are performed, no matter of their toggles.

!!! This function is returning the string $suffixString via echo. 
Therefore it needs to stay silent (no other output) with the exception of the
final 'echo $suffixString'
functionExplanation
	
	proctog=_${1}TOG #process-toggle
	suff=${1}SUFF
	suffixString=""
	global=GLOBAL${proctog}
# respect global toggle	
	if [[ ${!global} -eq 1 ]]; then
		#grep $global $CONFIG # for debugging only, make sure to comment-out before using
		for i in $(grep $proctog $CONFIG |cut -f 1 |grep -v ^# |grep -v 0 |grep -v GLOBAL|cut -d "_" -f 1); do 
			if [[ $(grep ${i}$proctog $CONFIG |awk -F "|" '{print $NF}' |cut -d " " -f 2) -eq 1 ]]; then
				#grep ${i}$proctog $CONFIG # for debugging only, make sure to comment-out before using
				if [[ "$proctog" == "_IPTOG" ]]; then
					suffixString="${suffixString} $(grep ${i}.*$suff $CONFIG |awk -F "|" '{print $NF}' |cut -d " " -f 2)"
				else
					suffixString=${suffixString}$(grep ${i}.*$suff $CONFIG |awk -F "|" '{print $NF}' |cut -d " " -f 2)
				fi
			fi
		done
	else
		#dbg "preprocessing toggled off globally"
		suffixString=""
	fi
	echo $suffixString
}

writeSubIndices() {
<<functionExplanation
This function searches for each raw data set in $INDEX and separates them into 
sub-indices.
functionExplanation

	intro "writeSubIndices on $stacktype"
	
# $stacktype is a global variable set/defined outside this function
# initial clean-up
	stindex=$INDEXDIR/$D.$HN.${ss}.$stacktype.index
	rm $INDEXDIR/$D.$HN.${ss}.$stacktype*.index 2> /dev/null
	touch $stindex

# separate $INDEX into file-type-specific sub-lists (stacktype index, ${stindex}). 
	for imgPath in $(grep ${stacktype}$ $INDEX); do
		dbg3 $imgPath
		echo $imgPath >> $stindex
		bn=$(basename $imgPath $stacktype |cut -d "." -f 1)
		msg "$bn"
	done
}

exportIndex() {
	intro "exportIndex"
# export all index files to central storage location for use by other applications
	xc="$EXCHANGEDIR/index/"
	if [[ $SEARCHSTRING == "." ]]; then # export indices only, if they are complete.
		mkdir -p --mode=750 $xc
		for index in $(find $INDEXDIR -name "${D}.*.index" |grep $stacktype |grep -v todo |grep -v all); do
			outpath=$(echo $index |sed -e "s@${INDEXDIR}/@${xc}@" -e "s@${D}.@@")
			dbg "$index $outpath"
			cp -v $index $outpath 2>&1 >> $LOG
		done
		sudo chown -R $ADMIN:$GROUP $xc 2>&1 |tee -a $LOG
		sudo chmod -R 750 $xc 2>&1 |tee -a $LOG
		date >>$LOG
	fi
}

#============================
# function calls
#============================

# find and source getVar.sh to set all global variables
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 || "$1" =~ "-" ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
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

debug=3

dbg "starting ..."
dbg2 $permissibleAgeOfIndex

# set default values 
DEFAULTINDIR=$LABDATADIR/$IMPORTS/
INDIR=$DEFAULTINDIR
SEARCHSTRING="."
FORCEINDEX=0
HN=$(hostname)
stop=0

# get parameters/options passed at call of this script
# TODO: add -t to also look for 'tiles' ???
while getopts ":p:d:fh" opt; do
	case $opt in
		p)
			guardian $OPTARG
			dbg2 "Option -p was triggered, argument: $OPTARG"
			#if [[ "$OPTARG" != "alldata" ]]; then
				SEARCHSTRING=$OPTARG
			#fi
			;;
		d)
			guardian $OPTARG
			dbg2 "Option -d was triggered, argument: $OPTARG"
			if [[ -d $OPTARG ]]; then
				INDIR=$(realpath $OPTARG)
			else
				error "$OPTARG is not a directory."
				usage
			fi
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
dbg "$PSTRING $DSTRING $FSTRING"

dbg "search string: $SEARCHSTRING"

dbg2 $(date)
#D=$(date +%y%m%d)

# ensure INDEXDIR exists
dbg "INDEXDIR: $INDEXDIR"
if [[ ! -d $INDEXDIR ]]; then
	mkdir -p --mode=750 $INDEXDIR
fi
# ensure LOGDIR exists
dbg "LOGDIR: $LOGDIR"
if [[ ! -d $LOGDIR ]]; then
	mkdir -p --mode=750 $LOGDIR
fi

# define index file and location
if [[ "$SEARCHSTRING" == "." ]]; then
	INDEX=$INDEXDIR/$D.$HN.alldata.index
	ss="-"
else
	INDEX=$INDEXDIR/$D.$HN.$SEARCHSTRING.index
	ss=$(echo "${SEARCHSTRING}" |sed 's@ @_@g')
fi
dbg2 "INDIR: $INDIR"

# decide which directory to index
if [[ -z $INDIR ]]; then
	warn "$INDIR does not exist. Falling back to $DEFAULTINDIR."
	INDIR=$DEFAULTINDIR
fi

# Write list of raw data or reuse existing one, if it is not too old.
if [[ $(find $INDEX -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2>/dev/null |wc -l) -eq 1 ]] && [[ $FORCEINDEX -eq 0 ]];  then 
<<functionExplanation
	The statement '$(find $INDEX -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2> /dev/null)' 
	is TRUE, when $INDEX is younger than $permissibleAgeOfIndex .
	$FORCEINDEX is TRUE when '-f' is set in the call of this script.
functionExplanation
#TODO: backup $INDEX #???

	ls -l $INDEX  2>&1 |tee -a $LOG
	stop=1
	warn "$INDEX is younger than $permissibleAgeOfIndex minutes. Skipping all index generation." |tee -a $LOG
else
	if [[ "$SEARCHSTRING" == "." ]]; then
		dbg " Writing ${INDEX}. \n\tDepending on the number of files this may take some time. \n\tPlease be patient."
# TODO: catch option -t here
		find $INDIR/ -type f |grep -E /[0-9]{6} |grep -v lock |grep -v _QC |grep -v tiles  > $INDEX
	else
		dbg " Writing ${INDEX} for ${SEARCHSTRING}. \n\tThis should be rather quick. \n\tAnyhow, please be patient."
# TODO: catch option -t here
		find $INDIR/ -type f -name "*${SEARCHSTRING}*" |grep -E /[0-9]{6} |grep -v lock |grep -v _QC |grep -v tiles  > $INDEX
	fi		
<<functionExplanation
find $INDIR/                   --> search in $INDIR
	-type f                    --> find exclusively files (no directories)
	-name "*${SEARCHSTRING}*"  --> include only files which names contain $SEARCHSTRING
	|grep -E /[0-9]{6}         --> which file names start with a six-digit timestamp
	|grep -v lock              --> exculde lock-files
	|grep -v _QC               --> exculde _QC-files (quality check files)
	|grep -v tiles             --> exculde tiles 
	> $INDEX                   --> (over-)write $INDEX with new list 
functionExplanation
	date
# clean paths and filenames from non-ASCII characters (
	bash $CHECKPATH $INDEX
fi

# remove leftover lock-files 
if [[ $FORCEINDEX -eq 1 ]]; then
	for i in $(find $INDIR -name "*.lock" |grep $SEARCHSTRING); do 
		if [[ -f $i ]]; then
			if [[ $debug -gt 0 ]]; then
				rm -fv $i
			else
				rm -f $i
			fi
		fi
	done
fi	

if [[ $stop -eq 0 ]]; then
	for stacktype in $(echo $STACKEXTENSION); do
		writeSubIndices
		exportIndex
	done
fi
date
