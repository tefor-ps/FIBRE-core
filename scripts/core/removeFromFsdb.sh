#!/bin/bash
<<README
This script removes the files, which are matching the input string from the fsdb.

This script expectes as parameter a searchstring   
$1 [ search string]

optionally the option -a can be given, which triggers automatic execution - no 
confirmation by the user.
README
#fsdb-rev-date: 251112

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

# make sure, $DUMPDIR exists
sudo mkdir -pv $DUMPDIR
# define parameters for interactive use 
autoYes=0

usage() {
	printf "Usage: $(basename $0) [-a] [-h] search-string

	-a auto yes
			This triggers automatic confirmation of the delete and is implemented for 
			calling this script from a script (unsupervised)
			
	-h	help
			Displays this help.

	search-string
			This on-word-string defines the population of files to delete.
" 1>&2;
	exit 1;
}

guardian() {
<<functionExplanation
The guardian is avoiding the assignment of options (e.g. -p) as arguments by
excluding everything, which starts with a hyphen from the pool of possible
arguments.
TODO: make this more standard 
https://unix.stackexchange.com/questions/249869/meaning-of-101/249870
functionExplanation
	if [ "$(echo ${1:0:1})" == "-" ]; then
		warn "Guardian says: Invalid argument: $1" >&2
		usage
	fi
}

# get parameters/options passed at call of this script
#https://unix.stackexchange.com/a/426486
while getopts ":a" opt; do
	case $opt in
		a)
			guardian $OPTARG
			dbg2 "Option -a was triggered, argument: $OPTARG" 
			autoYes=1
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

confirmDeletion() {
	if [ $autoYes -eq 0 ]; then
		warn "Do you want to delete this file? [Y/n]"; 
		read ans;
	else
		ans=y
	fi
	case $ans in
		[Yy]|[Yy][Ee][Ss]|"")
			sudo mv -v $1 $DUMPDIR |tee -a $LOG
#			sudo rm -rvf $1
			;;
		[Nn]|[Nn][Oo])
			echo "$1 not deleted"
			;;
		*) 
			echo "This input is invalid. Try again."
			confirmDeletion $1
			;;
	esac
}


INDEX=$(ls $INDEXDEIR/*alldata.index |sort  |tail -1)
if [[ -z $1 ]]; then
	error "this script needs a search string as parameter. Exiting."
	exit
else
	SS=$1
fi

# display all hits
grep $SS $INDEX

for i in $(grep $SS $INDEX ); do 
# make corresponding path to STORAGEDIR
	st=$(echo $i |sed "s@$LABDATADIR@$STORAGEDIR@");
	
# get nodeID for both locations
	iinode=$(ls -li $i |cut -d " " -f 1)
	stinode=$(ls -li $st |cut -d " " -f 1)
	if [[ $iinode == $stinode ]]; then
		# display status of both files 'before'	
		ls -li $i;
		ls -li $st;
# interactive control point
		confirmDeletion $i
		confirmDeletion $st
	else
		warn "nodeIDs are different: i: $i , st: $st" |tee -a $LOG
	fi
done
