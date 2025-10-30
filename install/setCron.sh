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

if [[ -f "$gv" ]]; then
	source "$gv"
else
	fail "Can't find getVar.sh"
fi

cron=/etc/cron.d/$FSDBVERSION

dbg "setting up crontab $cron"

function editCron() {
#	intro "Do you want to modify the schedule of the fsdb? [y/N]: "
			backup $cron $ADMINDIR
			editor $cron
}

# print header text into temporary file
if [[  -f $cron ]]; then
	msg "$cron exists already.\n"
else	
# print cron-header into fsdb-specific cron-file (by default within /etc/cron.d/) 
	printf "\# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the 'crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.
	
	SHELL=/bin/bash
	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
	
	# m h dom mon dow user  command\n" |sudo tee $cron
fi

grep _CRON $CONFIG |grep -v "^#" |cut -d "|" -f 3 |sed -e 's@^ @@' -e 's@#.*@@' |while read new; do
	s=$(echo "$new" |sed -e 's@.*\$@$@' -e 's@ .*@@' -e 's@[${}]@@g')
	if [[ -f $cron && $(grep -c $s $cron) -gt 0 ]]; then 
		grep $s $cron |sort -u |sed 's@\*@\\\\*@g' |while read old; do
			dbg "replace: $old --> $new"
			dbg2 "sed -i \"s@$old@$new@g\" $cron"
			sed -i "s@$old@$new@g" $cron
		done
	else 
		dbg "add: $new" 
		echo "$new" |tee -a $cron 
	fi
done

msg "Scheduling finished.\n\n"

dbg "crontab set up at $cron"
cat cron
echo

skipPerm "Do you want to modify the schedule of the fsdb?" editCron

dbg "crontab set up at $cron"
