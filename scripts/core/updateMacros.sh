#!/bin/bash
<<README
This script is updating the fiji macros from their import loactions (e.g., fsdb/core/Fiji.app/macros/...) 
with the active location (fsdb/Fiji.app/macros/fsdb.core/...)

no parameter needed

README

#debug=2

#DEPRECATED?

thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh
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
