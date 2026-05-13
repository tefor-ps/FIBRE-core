#!/bin/bash
<<README
This script removes the raw data (only) from inputPath.

README

#fsdb-rev-date: 251112

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

debug=2

# make sure, $DUMPDIR exists
sudo mkdir -pv $DUMPDIR
# define parameters for interactive use 
autoYes=0

confirmDeletion() {
	if [ $autoYes -eq 0 ]; then
		warn "/\\/\\/\\/\\/\\"
		ls -li $1
		warn "Do you want to delete this file? [Y/n]"; 
		read ans;
	else
		ans=y
	fi
	if [ $autoYes -eq -1 ]; then
		ans=n
	fi
	case $ans in
		[Yy]|[Yy][Ee][Ss]|"")
			intro "moving $1 to $DUMPDIR" |tee -a $LOG
			sudo mv -v $1 $DUMPDIR |tee -a $LOG
		#	sudo rm -rvf $1
			;;
		[Nn]|[Nn][Oo])
			warn "$1 not deleted" |tee -a $LOG
			;;
		*) 
			error "This input is invalid. Try again."
			confirmDeletion $1
			;;
	esac
}

# find raw data
stacktype=$(grep STACKEXTENSION $CONFIG |cut -f 1 |cut -d " " -f 2-)
rawdata=$(for i in $stacktype; do ls $inPath |grep \.$i$; done)

for i in $inPath/$rawdata; do 
	if [[ -f $i ]]; then
	# make corresponding path to STORAGEDIR
		st=$(echo $i |sed "s@$LABDATADIR@$STORAGEDIR@");
		
	# get nodeID for both locations
		iinode=$(ls -li $i |cut -d " " -f 1)
		stinode=$(ls -li $st |cut -d " " -f 1)
		if [[ $iinode == $stinode ]]; then
			msg "nodeID identical.\n"
			autoYes=1
		else
	# display status of both files 'before' deletion	
			ls -li $i
			iSize=$(ls -li $i |cut -d " " -f 6)
			ls -li $st;
			stSize=$(ls -li $st |cut -d " " -f 6)
			if [[ $iSize == $stSize ]]; then 
				warn "nodeIDs are different but Sizes are identical"
				autoYes=1
			else 
				error "nodeIDs and Sizes are different: \n\t$iinode\t$iSize\t${i}\n\t$stinode\t$stSize\t$st" |tee -a $LOG
				autoYes=-1
			fi
		fi
	# interactive control point
		confirmDeletion $i
		confirmDeletion $st
	else
		error "$i does not exists (anymore)"
	fi
done