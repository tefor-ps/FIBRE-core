#!/bin/bash
<<README
This script is the last step of the HCS-renaming at the TPS
It consists of the following steps:
- download the export sheet of the TPS-HCS-tmog-download as defined by $docID and $sheetID below --> $TMOG
- build an index of the HCS-folder on the microscope (/shares/nikon/HCS) <-- this accelerates the search and association of the files to their TPS-names   
- permutate through the cells of $TMOG, break the contents into $well and $tpsFN and move the input files to the $outDir using $tpsFn

Prerequisites:
- dos2unix

README

# set variables
thisDir=$(dirname $(realpath $BASH_SOURCE))
# if part of the fsdb, set global variables accordingly
if [[ -f $thisDir/../core/getVar.sh ]]; then
	source $thisDir/../core/getVar.sh
	LOG=$LOGDIR/${D}.TPS-HCS-renamer-log.txt
	#INDEX=$EXCHANGEDIR/${D}.tps-hcs-tmog.index
	INDEX=$INDEXDIR/${D}.tps-hcs-tmog.index
	outDir=$STORAGEDIR/$IMPORTS/HCS_rename
else
	LOG=$thisDir/../../logs/${D}.TPS-HCS-renamer-log.txt
	INDEX=/DATA/tps/labdata/exchange/index/${D}.tps-hcs-tmog.index
	mkdir -p $(dirname $INDEX)
	outDir=/DATA/tps/storage/imports/HCS_rename
	mkdir -p $outDir
fi

# define export table at google-drive 
docID=1nDwads-9MuEuNuqQijhXGgpqe22Ha93F-i4A9_b4l2c
sheetID=135128682
# define local documents
TMOG=tps-hcs.csv
# define output directory
mountPoint=/shares/nikon
mkdir -pv $outDir

echo "outDir: $outDir"
#exit

# download export table as csv
wget --output-file=$LOG "https://docs.google.com/spreadsheets/d/$docID/export?format=csv&gid=$sheetID" -O $TMOG
# make sure, the line-endings are correct
dos2unix $TMOG
# add a line-break to the end of the file, because it is missing
printf "\n" >> $TMOG
# debugging output
ls -l $TMOG
wc -l $TMOG
head $TMOG |cut -d "," -f 1


# make sure the microscope (and the hcsDir) is mounted
hcsDir=$mountPoint/HCS
	if [[ ! -d $hcsDir ]]; then
		if [[ -f $thisDir/mountMicroscopes.sh ]]; then
			sudo bash $thisDir/mountMicroscopes.sh
		else
			sudo mount -t cifs -o vers=2.0,credentials=$thisDir/.cred-nikon,iocharset=utf8,noperm //192.168.5.5/DATA $mountpoint
		fi
	fi
ls -l $outDir

# make index of files in /shares/nikon/HCS	
find $hcsDir -type f > $INDEX
# debugging output
ls -l $INDEX
head $INDEX
echo "for-loop"
# debug stop
#read ans

# for each entry in tps-hcs.csv, find the nikon-file, move it to output location and assign tps-name
while read line; do
# filter against header and erroneous lines
	if [[ $line =~ ^[0-9]{6}-[A-Z] ]]; then
		echo; 
# debugging output
		echo $line;
# turn line into array (so we can permutate over the individual entries)
		orgIFS=$IFS
		IFS=',' read -r -a lineArray <<< "$line"
		for entry in "${lineArray[@]}"; do
			if [[ $(echo $entry |grep -c @) -gt 0 ]]; then
# debugging output
				echo $entry
# separate entry into its components (well and tpsFN)
				IFS='@' read -r -a compArray <<< "$entry"
				well="${compArray[0]}"
				tpsFn="${compArray[1]}"
				printf "$well\t$tpsFn\n" >> $LOG
# define inPath				
				inPath=$(grep $well $INDEX)
# rename and relocate input to output
				if [[ -f $inPath ]]; then
					echo "move $inPath to $outDir/$tpsFn"
					mv -v "$inPath" "$outDir/$tpsFn" >> $LOG
				else
					echo "$well does not exist anymore" >> $LOG
				fi
			fi
		done
		ls -l $outDir
# change IFS back to original		
		IFS=$orgIFS
# debugging output
	else
		echo "XXX: $line"
	fi
done < $TMOG
sudo chown $ADMIN:$GROUP $LOG
