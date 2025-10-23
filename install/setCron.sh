#!/bin/bash
<<README
This script is setting up the recurrent execution of the fsdb scripts

README

#fsdb-rev-date: 251023

function fail(){
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

## ======
## FUNCTION CALLS
## ======

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

fi [[ -f "$gv" ]]; then
	source "$gv"
else
	fail "Can't find getVar.sh"
fi

cron=/etc/cron.d/$FSDBVERSION

dbg2 "setting up crontab"

function editCron() {
	read -e -p "Do you want to modify the schedule of the fsdb? [y/N]: " -i "N" ans
	case $ans in
		[Yy])
			backup $cron $ATTICDIR
			editor $cron
			;;
		*) 
			msg "Skipping upgrade.\n"
			;;
	esac
}

# print header text into temporary file
if [[  -f $cron ]]; then
	msg "$cron exists already.\n"
else	
	# append fsdb-specific line to temporary file 
	printf "\# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the 'crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.
	
	SHELL=/bin/bash
	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
	
	# m h dom mon dow user  command
	30 22 * * * root ${JANITOR}
	# run with the 'save' option, fetchDataFromMicroscopes does NOT delete files from the microscopes
	13 7,12,19,23, * * * root ${FETCHDATA} save
	45 */6 * * * root ${SECDATAGEN}\n" |sudo tee $cron
	
	msg "Scheduling finished.\n"
fi

editCron

dbg "crontab set up at $cron"
