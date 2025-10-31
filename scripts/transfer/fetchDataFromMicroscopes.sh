#!/bin/bash
<<README
This script is transferring original data from the acquisition instruments to the 
storage server ($STORAGEDIR/$IMPORTS), generates links to $LABDATADIR/$IMPORTS and 
cleans up the acquisition instrument's storage space 

mode of function:
- connect to the microscope computers <-- $SCRIPTSDIR/$MOUNTMICS
- copy all files, which are older than ten minutes to the corresponding location on the server <-- parallel rsync
- remove transferred files from the microscope computer
- on the storage server, move data into corresponding -fsdb folders at $STORAGEDIR/$IMPORTS
- generate hard links to $LABDATADIR/$IMPORTS
- reconfirm that all links exists between $STORAGEDIR/$IMPORTS and $LABDATADIR/$IMPORTS <-- $SCRIPTSDIR/$CLEANIMPORTS
- start secondary data generation in the background --> $SCRIPTSDIR/$SECDATAGEN &

attention:
Long lasting image acquisitions (e.g. Leica HCS) are often stored in many small image files. 
This may result in incomplete transmission of the currently active scan. 
The transfer of that scan will be completed as soon as this script is run again - after the scan is complete.

parameters:
  -s --> 'save': prevents deletion of the transferred files from the source.
  -p --> 'pattern': restricts the transfer to files containing ,string. in their filename.

README

# find getVar.sh
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 ]]; then
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
	fail "Can't find getVar.sh"
fi

# log file for debugging and cleanup 
#TODO: check if deprecated
mkdir -p $LOGDIR
LOG="$LOGDIR/$D.$(basename $0 .sh).log"
echo "logs at $LOG"
date >> $LOG

intro $0

debug=2

# get parameters
usage() { 
	echo "Usage: $0 [-s ] [-p <string>]" 1>&2
	echo "  -s --> 'save': prevents deletion of the transferred files from the source."
	echo "  -p --> 'pattern': restricts the transfer to files containing ,string. in their filename."
	exit 1; 
}

while getopts ":sp:" o; do
    case "${o}" in
        s)
            save=1
            ;;
        p)
            pattern=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# run external script, which is mounting the shared folders of the microscopes
dbg "mounting microscopes"
bash $MOUNTMICS

# timestamp for index files
D=$(date +%y%m%d)

for share in $(grep -P ^mountMic $MICS |cut -d " " -f 4); do 
	for member in $(echo $USER); do
		date |tee -a $LOG
		dbg "$share :: $member" |tee -a $LOG
		if [[ ! -d $share/$member/ ]]; then
			dbg "$share/$member/ does not exist; skipping." |tee -a $LOG
			continue
		fi
		mkdir -p $STORAGEDIR/$IMPORTS/${member}/
		dbg2 "mkdir -p $STORAGEDIR/$IMPORTS/${member}/" |tee -a $LOG
# replace white spaces with underscores in source files 
		find $share/$member/ -mmin +10 -name "* *" |rename 's/ /_/g' |tee -a $LOG 2>&1
# get list of files on microscopes
		for ext in $(echo $STACKEXTENSION); do
			if [[ ! -z $pattern ]]; then
				fileList=$(find $share/$member/ -type f -name "*.$ext" -mmin +10 |grep -v RECYCLE |grep $pattern)
			else
				fileList=$(find $share/$member/ -type f -name "*.$ext" -mmin +10 |grep -v RECYCLE)
			fi
			dbg $fileList |tee -a $LOG
			if [ ! -z "$fileList" ]; then
# transfer file from microscopes to STORAGEDIR on server
				for i in $(echo $fileList); do
					dbg $i
# get file extension				
					suff=$(echo $i |awk -F "." '{print $NF}')
					dbg2 $suff
# generate file name and basename
					fn=$(basename $i)
					bn=$(basename $i .$suff)
					dbg2 $bn |tee -a $LOG 2>&1
# generate '-fsdb' folders on storage server
			#		mkdir -pv $STORAGEDIR/$IMPORTS/${member}/$outDir  |tee -a $LOG 2>&1 # on the storage server
					mkdir -pv $STORAGEDIR/$IMPORTS/${member}  |tee -a $LOG 2>&1 # on the storage server
# transfer data from microscope to storage server
					if [ $save -eq 1 ]; then
			#			dbg "move $i to $STORAGEDIR/$IMPORTS/${member}/$outDir/ "
						dbg "move $i to $STORAGEDIR/$IMPORTS/${member}/ "
			#			rsync -Sauv --remove-source-files "$i" $STORAGEDIR/$IMPORTS/${member}/$outDir/ |tee -a $LOG 2>&1
						rsync -Sauv --remove-source-files "$i" $STORAGEDIR/$IMPORTS/${member}/ |tee -a $LOG 2>&1
					else
			#			dbg "copy $i to $STORAGEDIR/$IMPORTS/${member}/$outDir/ "
						dbg "copy $i to $STORAGEDIR/$IMPORTS/${member}/ "
			#			rsync -Sauv "$i" $STORAGEDIR/$IMPORTS/${member}/$outDir/ |tee -a $LOG 2>&1
						rsync -Sauv "$i" $STORAGEDIR/$IMPORTS/${member}/ |tee -a $LOG 2>&1
					fi
					dbg "$share :: $member :: $i"  |tee -a  $LOGDIR/$D.transferred.txt
					dbg "$share :: $member :: $i"  |tee -a  $LOG 2>&1
				done
# clean up microscope drives
				find $share/$member/ -type d -mmin +10 -empty -delete |tee -a $LOG 2>&1 
				mkdir -pv $share/$member/  |tee -a $LOG 2>&1
# recreate '-fsdb' folder in LABDATADIR and link content into
				for i in $(echo $fileList); do	
# make corrsponding folder in LABDATADIR
			#		mkdir -pv $LABDATADIR/$IMPORTS/${member}/$outDir  |tee -a $LOG 2>&1
					mkdir -pv $LABDATADIR/$IMPORTS/${member}  |tee -a $LOG 2>&1
# create hardlink between files in STORAGEDIR and LABDATADIR
			#		ln -v $STORAGEDIR/$IMPORTS/${member}/$outDir/$fn $LABDATADIR/$IMPORTS/${member}/$outDir  |tee -a $LOGDIR/$D.transferred.txt  |tee -a $LOG 2>&1
					ln -v $STORAGEDIR/$IMPORTS/${member}/$fn $LABDATADIR/$IMPORTS/${member}  |tee -a $LOGDIR/$D.transferred.txt  |tee -a $LOG 2>&1
# adjust ownership and access permissions of files in LABDATADIR
			#		chown -R $GROUP:$GROUP $LABDATADIR/$IMPORTS/${member}/$outDir
					chown -R $GROUP:$GROUP $LABDATADIR/$IMPORTS/${member}
			#		chmod -R 770 $LABDATADIR/$IMPORTS/${member}/$outDir
					chmod -R 770 $LABDATADIR/$IMPORTS/${member}
# adjust ownership and access permissions of files in STORAGEDIR
			#		chown $ADMIN:$GROUP $STORAGEDIR/$IMPORTS/${member}/$outDir/$fn
					chown $ADMIN:$GROUP $STORAGEDIR/$IMPORTS/${member}/$fn
			#		chmod 750 $STORAGEDIR/$IMPORTS/${member}/$outDir/$fn
					chmod 750 $STORAGEDIR/$IMPORTS/${member}/$fn
				done
			else 
				dbg "filelist is empty." |tee -a $LOG 2>&1
			fi
		done
	done
done
date  |tee -a $LOG 2>&1
 

#bash $JANITOR

## start secondary data generation 
#bash $SECDATAGEN &
dbg "$0 done"  |tee -a $LOG 2>&1
