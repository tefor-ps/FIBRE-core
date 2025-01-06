#!/bin/bash
<<README
This script removes all files, which belong to the user-group root or 
$ADMIN and are older than 2 days from the tmp-directory. It also removes 
everything older than 2 days from  $LOGDIR and $INDEXDIR as well as the 
file 'debugger' from $MACROSDIR. 

Should there be empty directories left over after the file-removal, these will
be removed as well.

This script is part of the janitor-job

mode of function
- find and remove all files older than 2 days from $LOGDIR and $INDEXDIR
- remove debugging-notes (debugger) from $MACROSDIR
- find and remove all files older than 2 days from /tmp, as long as it belongs 
to 'root' or $ADMIN

README
#fsdb-rev-date: 230331

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0
dbg "starting ..."

# remove all log files older than 30 days
find $LOGDIR -type f -mtime +30 -delete >>$LOG 2>&1

# remove all index files older than 30 days
find $INDEXDIR -type f -mtime +30 -delete >>$LOG 2>&1

# remove debugger file
tail -n 1000 $LOGDIR/debugger >/tmp/debugger
rm -vf $LOGDIR/debugger >>$LOG 2>&1
mv -f /tmp/debugger $LOGDIR/debugger

# remove temporary files older than 30 days
rm -rvf $(sudo find /tmp/ -mtime +30 -group root) >>$LOG 2>&1
rm -rvf $(sudo find /tmp/ -mtime +30 -group $ADMIN)  >>$LOG 2>&1
find /tmp -type d -empty -delete  >>$LOG 2>&1
