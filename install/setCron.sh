#!/bin/bash
<<README
This script is setting up the recurrent execution of the fsdb scripts

README

# set all global variables
thisDir=$(dirname $(realpath $BASH_SOURCE))
if [[ -z $1 ]]; then
	source $thisDir/../scripts/core/getVar.sh
else 
	source $1/core/getVar.sh
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
