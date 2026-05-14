#!/bin/bash
<<README
This script is updating the fsdb by pulling the scripts from the online repositories


no parameter needed

README

# ensure correct reporting of failures within pipes
set -o pipefail

## =====================
## DEFINITION OF HELP FUNCTION
## =====================

force=0
defaultBranch=stable
branch=$defaultBranch

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

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# get variables of fsdb from getVar.sh
if ! source getVar; then
	dir=$thisDir 
	for _ in $(seq 1 4); do
		GV=$(find "$dir" -name "getVar.sh" -print -quit)
		if [[ -f $GV ]]; then 
			source "${GV}"
			break 
		else
			dir="$(dirname "$dir")"
		fi
	done
	if [[ ! -f "${GV}" ]]; then
		echo "ERROR: Can't find getVar.sh"
		exit 555
	fi
fi
intro $(basename $0)

# define local debug level (overwrites global one). Comment out to follow global debug level.
debug=3

cd $FSDBDIR
dbg $FSDBDIR
for dir in $(dirname $(find $FSDBDIR -name ".git" )); do 
	echo
	cd $dir
	dbg2 $(pwd)
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
