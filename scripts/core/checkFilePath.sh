#!/bin/bash
<<README
This script removes files with special characters in their filenames from the provided index. 

I replaces whitespaces with unserscores.


README
#fsdb-rev-date: 251105

#TODO: implement automatic replacement of non-ASCII characters 
# e.g. dynamically create and grep from look-up-table 
# e.g. "e éè..." <-- grep $i |cut -d " " -f 1)

# debugging variables
interactive=0

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

debug=2

# set default values 
INFILE=$INDEX

# get parameters/options passed at call of this script
while getopts ":i:h" opt; do
	case $opt in
		i)
			dbg2 "Option -i was triggered, argument: $OPTARG"
			INFILE=$(realpath $OPTARG)
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

dbg "INFILE: $INFILE"

# filter index against unvalid characters
# motivated by https://www.baeldung.com/linux/find-non-ascii-chars#:~:text=Non%2DASCII%20characters%20are%20those,ASCII%20characters%20within%20text%20files.
# and https://donsnotes.com/tech/charsets/ascii.html
if [[ $(grep -c -P "[^\x00-\x1F\x30-\x39\x41-\x5A\x61-\x7A\x2E\x2D\x5F\x2F]" $INFILE) -gt 0 ]]; then
	PROBLEMATIC=$(echo $INFILE |sed 's@.index$@.problematic@')
	TMP=$(echo $INFILE |sed 's@.index$@.tmp@')
	TMP2=$(echo $INFILE |sed 's@.index$@.tmp2@')
	if [[ -f $PROBLEMATIC ]]; then
		cat $PROBLEMATIC > $TMP2 # transfer content of pre-existing list of problematic filenames to temp file
	fi
	warn "The follwing file names are problematic!" 
	grep --color='auto' -P "[^\x00-\x1F\x30-\x39\x41-\x5A\x61-\x7A\x2E\x2D\x5F\x2F]" $INFILE |tee -a $TMP
	cat $TMP $TMP2 |sort -u | tee $PROBLEMATIC # fuse 'old' and 'new' problematic filenames (uniquely)
# remove problematic filenames from index
	FILTERED=$(echo $INFILE |sed 's@.index$@.filtered@')
	grep -v -f $PROBLEMATIC $INFILE > $FILTERED
	mv $FILTERED $INFILE
# fix filenames with white-spaces by replacing them with underscores
	grep -P "[\x20]" $PROBLEMATIC |while read line; do
		if [[ ! -d "$line" ]]; then
			out=$(echo "$line" |sed 's@ @_@g') 
			warn "renaming $line to $out"
			mkdir -pv $(dirname $out)
			mv -v "$line" $out
			if [[ $? -eq 0 ]]; then
# remove line from PROBLEMATIC
				sed -i "s@$line@@" $PROBLEMATIC
# add corrected filename back to index
				echo $out >> $INFILE
			fi
		fi
	done
fi	
