#!/bin/bash
<<README
This script is cleaning the $EXCHANGEDIR 
It moves everything older than 30 from $EXCHANGEDIR into the $DUMPDIR

This script is part of the janitor-job

mode of function:
- find all files in $EXCHANGEDIR, which are older than 30 days
- generate corresponding directory in $DUMPDIR
- move these files to $DUMPDIR
- delete remaining empty folders from $EXCHANGEDIR

README
#fsdb-rev-date: 230331

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0

#debug=3

tmpList=/tmp/cleanExchange.txt

## clean exchange
# make list of files to dump (trashlist)
find $EXCHANGEDIR/ -mtime +30 |grep -v $INDEXDIR > $tmpList
# move items on trashlist to dump
while read i; do
	dump=$(dirname $i |sed "s@$EXCHANGEDIR@$DUMPDIR@")
	dbg "$dump"
	mkdir -p "$dump"
	mv -f "$i" "$dump"
done < $tmpList  >>$LOG 2>&1
find $EXCHANGEDIR -type d -empty -delete >>$LOG 2>&1

rm $tmpList


