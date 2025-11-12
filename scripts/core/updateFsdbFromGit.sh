#!/bin/bash
<<README
This script is updating the fsdb by pulling the scripts from the online repository
and updating the macros in their active locations 

no parameter needed

README
# fsdb revision 251023

#DEPRECATED?

# find and source getVar.sh to set all global variables
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 || "$1" =~ "-" ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
else
	if [[ -d $1 ]]; then
		gv=$(find "$1" -type f -name getVar.sh)
	else
		gv=$(find $(dirname "$1") -type f -name getVar.sh)
	fi
fi

if [[ -f "$gv" ]]; then
	source "$gv"
else
	echo "ERROR: Can't find getVar.sh"
	exit 555
fi

intro $(basename $0)

#debug=2

cd $FSDBDIR

# get latest version from online repository
git stash
git reset --hard HEAD
git pull

# update macros in their active location
bash $UPDATEMACROS
