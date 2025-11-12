#!/bin/bash
<<README
This script is updating the fiji macros from their import loactions (e.g., fsdb/core/Fiji.app/macros/...) 
with the active location (fsdb/Fiji.app/macros/fsdb.core/...)

no parameter needed

README

#debug=2

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

scriptsDir=$(realpath $thisDir/../)

dbg $SCRIPTSDIR

find $SCRIPTSDIR -type d |grep macros/fsdb |grep -v $FIJIDIR| while read i; do
	ibn=$(basename $i)
	mkdir -p $FIJIDIR/macros
	out=$(echo $i |sed "s@$SCRIPTSDIR/.*@$FIJIDIR/macros/$ibn@")
	dbg2 "rsync -Sauv $i/ $out/"
	if [[ $debug -gt 1 ]]; then
		rsync -Sauv $i/ $out/
	else
		rsync -Sau $i/ $out/
	fi
done
