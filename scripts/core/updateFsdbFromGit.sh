#!/bin/bash
<<README
This script is updating the fsdb by pulling the scripts from the online repositories


no parameter needed

README
# fsdb revision 251023

# ensure correct reporting of failures within pipes
set -o pipefail

## =====================
## DEFINITION OF HELP FUNCTION
## =====================

force=0
defaultBranch=stable
branch=$defaultBranch
# define local debug level. Comment out to follow default debug level (1).
debug=3

function usage() {
<<readme
INFO
CALL
INPUT
OUTPUT
readme
		printf "\nUsage: sudo bash $0 [-h] [-f]
		" 1>&2
	exit 1
}

while getopts "hfm" opt; do
	printf "Option -$opt was triggered. " >&2 
	case $opt in
		h)
			usage
			echo
			;;
		f)
			force=1
			;;
		m)
			branch=main
	esac
done
shift $((OPTIND-1))

# set debug level (default 1) by variable of parameter 
getLevel() { 
	if [[ -z $debug ]]; then 
		if [[ -z $DEBUGLEVEL ]]; then 
			debug=1; 
		else 
			debug=$DEBUGLEVEL ; 
		fi ; 
	fi ; 
	echo $debug ;
}

# error message; white on red background
error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}
# green message, no new line
msg() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[32;1;40m'"$(basename $0): $@"$'\e[0m\r' || echo "$@"; else echo "$@"; fi >&1 ;}
# red warning message
warn() { if [[ -t 2 ]] ; then date >> $LOG 2>/dev/null; printf $'\r\e[2K\t\e[31;1;40m'"$(basename $0): $@"$'\e[0m\n' |tee -a $LOG 2>/dev/null; else echo "$@"; fi >&1 ;}
# magenta debuggin message level 1 (most prevalent)
dbg() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 1 ]]; then printf $'\r\e[2K\t\e[35;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# beige debugging message level 2
dbg2() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 2 ]]; then printf $'\r\e[2K\t\e[33;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# dark-blue debugging message level 3
dbg3() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 3 ]]; then printf $'\r\e[2K\t\e[34;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# cyan text on black background to introduce the current script or say something important
intro() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[36;1m'"$@"$'\e[0m\n'; else echo "$@"; fi >&2 ;}


intro $(basename $0)

# get location of this script
thisDir=$(dirname $(realpath "$0"))
# get location of FSDBDIR (root of fsdb scripts)
FSDBDIRSTRING=$(echo $thisDir | grep -oE 'fsdb[0-9]{2}')
FSDBDIRSTATUS=$?
FSDBDIR=$(echo $thisDir |sed "s@$FSDBDIRSTRING.*@$FSDBDIRSTRING@")
# define log
LOGDIR=$FSDBDIR/log
D=$(date +%y%m%d)
LOG=$LOGDIR/${D}.$(basename $0 .sh).log
# exit gracefully, if FSDBDIR can't be found.
if [[ $FSDBDIRSTATUS -ne 0 ]]; then
	error "Can't find FSDBDIR of $(pwd). Exiting."
	exit
fi

cd $FSDBDIR
dbg $FSDBDIR
for dir in $(dirname $(find $FSDBDIR -name ".git" )); do 
	echo
	cd $dir
	dbg2 $(pwd)
# update knowledge of the remote.
	dbg2 "git fetch"
	git fetch
# select the right branch
	dbg2 "git checkout $branch"
	git checkout $branch
	if [[ $? -ne 0 ]]; then
		error "$dir doesn't have branch $branch. Skipping."
	else
# get latest version from online repository
		dbg2 "git stash"
		git stash
		if [[ $force -eq 1 ]]; then
			dbg2 "git reset --hard HEAD"
			git reset --hard HEAD
		fi
		dbg2 "git pull"
		git pull
	fi
done