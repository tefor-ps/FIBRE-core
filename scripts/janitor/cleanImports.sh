#!/bin/bash
<< README
This script generates hard links between the original data in the protected 
location ($STORAGEDIR/$IMPORTS/) and the accessible location ($LABDATADIR/$IMPORTS) 
and vice versa.

All variables are defined in the configuration file which is defined in getVar.sh

Parameters - none.

mode of function
- this script expects raw data (see $STACKEXTENSION) in the $USERs folder at 
$STORAGEDIR/$IMPORTS/.
- it generates a corresponding folder at e.g., $LABDATADIR/$IMPORTS 
and creates a hard link for the raw data set within that folder.
- subsequently it does the same in reverse: synchonizing the raw data in 
$LABDATADIR/$IMPORTS with $STORAGEDIR/$IMPORTS
- last but not least it makes sure, that the permission settings for the $IMPORTS 
folders are correct.

README
#fsdb-rev-date: 230331

#TODO: this script currently is running (completely) as many times as users are defined. That's wasteful, fix this, so that it only runs once. looks like the dir-name (e.g., Arnim, Dorian) is not communicated correctly (in the find?)

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0

#debug=3

#============================
# FUNCTION DEFINITIONS
#============================

makeFsdbDir(){
# move files in $STORAGEDIR into their folder
		DIR=$1
		dbg "moving raw data of type ${stacktype} in $DIR/$IMPORTS/${user} into its fsdb-directory" |tee -a $LOG 
		for i in $(find $DIR/$IMPORTS/${user}/ -maxdepth 1 -mmin +10 -type f -name "*.$stacktype"); do
			fsdbCount=$(dirname $i |tr "/" "\n" |grep -ce -fsdb)
			if [[ $fsdbCount -eq 0 ]]; then
				echo "moving $i into fsdb-location. Skipping." >> $LOG
				out=$(echo "$i" |sed "s@\.$stacktype@$FSDB_EXT@");
			elif [[ $fsdbCount -eq 1 ]]; then
				echo "$i already in fsdb-location. Skipping." >> $LOG
				out=$(dirname $i)
			else
				echo "$i in false fsdb-location. Relocating" >> $LOG
				out=$(dirname $i |sed "s@${FSDB_EXT}.*@${FSDB_EXT}@")
			fi
			msg "$i --> $out"  |tee -a $LOG
			dbg3 "$i --> $out"
# create fsdb-folder
			mkdir -v $out >>$LOG 2>&1
# move image into new folder
			mv -fv $i $out >>$LOG 2>&1
		done
}

makeLinks(){
	INDIR=$1
	OUTDIR=$2
	dbg "linking data from $INDIR to $OUTDIR" |tee -a $LOG
	DIR=$INDIR
	for DIR in $(find $INDIR/$IMPORTS/${user}/ -type d -name "*$FSDB_EXT"); do
		for IMAGE in $(find $DIR -type f -name "*.$stacktype"); do
			out=$(echo $IMAGE |sed "s@$INDIR@$OUTDIR@");
			outDir=$(dirname $out);
			msg $IMAGE
			mkdir -vp $outDir >>$LOG 2>&1
			ln -v $IMAGE $out >>$LOG 2>&1
		done
	done
}

for user in $USER; do
	dbg "working for $user" |tee -a $LOG
	for stacktype in $STACKEXTENSION; do
# make and populate fsdb-directories # DEPRECATED 
		makeFsdbDir $STORAGEDIR
		makeFsdbDir $LABDATADIR
# synchonize the raw data in $STORAGEDIR and $LABDATADIR
		makeLinks $STORAGEDIR $LABDATADIR
		makeLinks $LABDATADIR $STORAGEDIR
	done
done
echo "make sure all permissions are set correctly" |tee -a $LOG
date  |tee -a $LOG
bash $FIXPERMISSIONS
