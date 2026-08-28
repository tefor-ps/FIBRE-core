#!/bin/bash
<<README
This script is getting the values from the central configuration file ( $SCRIPTSDIR/.scripts.config ($CONFIG) ) 
and passses them to the sourcing script.

For the directories, which are defined in .scripts.config (variable-name ends on
'DIR') mkdir -p is run to make sure, that these directories really exist.

This script needs to be called via 'source'.

underlying concept:    
- for some variables all scripts of the fsdb need to work with identical values
- for differentiating these from 'local variables' the 'golbal variables' are 
	CAPITALIZED.
- 'global variables' are defined in the .scripts.config file.
- form of the .scripts.config file:   
-- first column: name of 'global variable'   
-- second column: name of application using/introducing this variable   
-- third column to end of line: value(s) of the 'global variable'   
To be on the save side columns are separated by the string " | " (space-pipe-space).

mode of function:   
- make sure, .scripts.config does exist. Create, if not.
- for each line in .scripts.config 'associate' the first word with the rest of 
	the line (export/source)
- for each directory, defined in .scripts.config, make sure, that is does exist 
	(mkdir -p)

debugging level:   
The verbosity of the debugging output can be set globally and locally, where the 
local setting is always overwriting the global one.   
0 - silent   
1 - some output   
2 - verbose   
3 - very verbose   

The global debugging level is defined by DEBUGLEVEL. If it is unset or invalid,
fun_colMsg.sh uses level 1.
The local debugging level is set (for each script individually) by the variable 
 'debug', which also can have the same values as the global levels (0-3)
	
Aside of ALL VARIABLES DEFINED IN .scripts.config this script explicitly exports/
populates the following variables:
- D : timestamp of today in YYMMDD
- STARTDATE : same as $D but in contrast to $D this will not be updated at midnight. 
	STARTDATE is used to keep referencing the $INDEX of the starting day even 
	if/while the process is running longer than midnight.
- SCRIPTSDIR : directory, which is containing all (shell) scripts of the fsdb.
- FSDBDIR : the root-directory of the fsdb

--> machine-specific configurations
- COMP : name of the computer this script is running on 
- maxsize : maximal file size that can be handled on this machine
- minsize : minimal filesize to b handled by this machine
- ORDER : sorted order of file list 
	(by default youngest first('age'), on big machines biggst first ('size'))
- FIJIONSERVER : potentially overwrites which script is used to run the 
	secData-Generator

Machine-specific values are resolved by fun_machineProfile.sh. The helper
normalizes the short hostname and reports the complete effective profile.

README
#fsdb-rev-date: 260828

# TODO: revise README

# Load the shared helpers before defining or executing getVar operations.
# Both helper files are side-effect-free when sourced. Resolve BASH_SOURCE
# first: getVar is intentionally exposed through /usr/local/bin/getVar, and
# helper paths must remain relative to the real script rather than the symlink.
getVarSource=$(realpath -- "${BASH_SOURCE[0]}") || {
	printf 'ERROR: Cannot resolve getVar source: %s\n' "${BASH_SOURCE[0]}" >&2
	return 1 2>/dev/null || exit 1
}
getVarDir=$(dirname -- "$getVarSource")
DEBUGLEVEL=${DEBUGLEVEL:-1}
source "$getVarDir/fun_colMsg.sh" || return 1 2>/dev/null || exit 1
source "$getVarDir/fun_machineProfile.sh" || return 1 2>/dev/null || exit 1

## ======
## FUNCTION DEFINITIONS
## ======

function checkConfig(){
	local mode=${1:-}

	# detect missing configuration file and create one from template, if needed.
	if [[ ! -f $config || ! -f $fsdbconfig ]]; then 
		intro "Welcome to the fsdb-setup.
	It appears, that you didn't set up the configuration of the system, yet.
	Since this is necessary for the correct installation of the fsdb, 
	it is strongly recommended to do this right now.
	Below is displayed the content of the default fsdb.config:"
		makeConfig
	else
	# reconfigure pre-existing installation, if demanded by passing parameter 'config' to getVar 
		if  [[ $mode == "config" ]]; then
			intro "Welcome to the reconfiguration of an existing fsdb-installation
	In the following you can change the configuration and layout of your fsdb-installation or create a completely new one."
			backup "$config"
			cat "$fsdbconfig"
			warn "$config already exists."
			skipRest "Above you find the contents of your current fsdb.config.\nDo you want to reset it to default values." resetConfig
			#editConfig
			editOrImport
		fi
	# update scripts.config, if needed.
		updateConfig
	fi
}

function makeConfig() {
# This function creates a new configuration file on the basis of the provided 
# default configuration and allows the user to modify it
	if [[ ! -f "$fsdbconfig" ]]; then
		resetConfig
	else
		ONLINEDOC="$(grep "^ONLINEDOC " "$fsdbconfig" |cut -d " " -f 2)" #TODO: $ONLINEDOC is the URL of the repo at gitlab.
		nohup xdg-open "$ONLINEDOC" &> /dev/null &
		# This is intended to open/access the online documentation (in the default browser) but is not at all implemented, yet. 
		# See https://stackoverflow.com/a/38147878/5269099
		backup "$fsdbconfig"
	fi
	editOrImport
	updateConfig
}

function editOrImport(){
	cat "$fsdbconfig"
	echo
	#skipPerm "Above you find the content of your $fsdbconfig. \nThe next step will give you the opportunity to edit a preformatted fsdb.config file in you default text editor.\nFor details on this please consult the README at this project's gitlab page:\n$ONLINEDOC \n\t- Preparing editor -" editConfig $fsdbconfig
	intro "Above you find the content of your $fsdbconfig. 
	The next step will give you the opportunity to edit a preformatted fsdb.config file in you default text editor.
	For details on this please consult the README at this project's gitlab page:
	$ONLINEDOC \n"
	intro "Do you want to proceed? [Y/n]: "
	read -p $'\t' -i "Y" -e ans
	case $ans in 
		[Yy]*)
			intro "\t- Preparing editor -\n" 
			editConfig $fsdbconfig
			;;
		[Ii]*)
			intro "\t- Importing config -\n"
			importConfig || fail
			;;
		[Nn]*)
			echo "ABORT BY USER"
			exit 1
			;;
		*)
			error "$ans in an invalid input. Try again."
			editOrImport
			;;
	esac	
	cat "$fsdbconfig"
	skipRest  "Above you find the content of your new/modified $fsdbconfig. Do you still want to modify it?" editOrImport
}

function importConfig(){
	ccd="$(find "$FSDBDIR" -name "core.config.default")"
	IMPORTCONFIG=$(find "$FSDBDIR" -name $(grep "^IMPORTCONFIG" $ccd |cut -d " " -f 2 |awk -F "/" '{print $NF}'))
	dbg "sudo bash $IMPORTCONFIG $FSDBDIR force"
	sudo bash $IMPORTCONFIG $FSDBDIR force
}

function resetConfig(){
#	fcd=$getVarDir/../install/templates/fsdb.config.default
	fcd="$(find "$FSDBDIR" -name "fsdb.config.default")"
	cp "$fcd" "$fsdbconfig" || fail
	ONLINEDOC=$(grep "^ONLINEDOC " $fcd |cut -d " " -f 2)
}

function editConfig(){
	#skipPerm "Do you want to modify your fsdb.config?\n" editor $fsdbconfig
	editor $1
	intro "Below you find the content of your new ${1}\n"
	cat "$1"
}

function updateConfig(){
	## List of configs to compare. 
	# config files in 'SCRIPTSDIR' <-- configs of core functions
	localConfigs=($(find "$(realpath "$SCRIPTSDIR")" -name "*.config" |grep -v "$config" ))
	dbg2 "localConfigs at $(realpath $SCRIPTSDIR)\n$(ls -l ${localConfigs[@]})"
	# ALL configs (core and modules) 
	moduleConfigs=($(find "$(realpath "$FSDBDIR")" -name "*.config" |grep -v -e "$config" -e "install" ))
	dbg2 "moduleConfigs at ${FSDBDIR}\n$(ls -l ${moduleConfigs[@]})"
	# fuse lists (arrays) of configs and ...
	configs=("${localConfigs[@]}" "${moduleConfigs[@]}")
	# ... make the values in the resulting arrayunique.  
	configs=($(echo "${configs[@]}" |tr " " "\n" |sort -u |tr "\n" " "))
	dbg2 "all configs\n$(ls -l ${configs[@]})"
	
	# re-check if $config exists, if not create it
	if [ ! -f "$config" ]; then
		touch "$config"
		update=1
	else
	# Set a flag to indicate whether $config needs to be updated (default: no update)
		update=0
	fi
	
	# Get the modification time of $config
	config_time=$(stat -c %Y "$config")
	dbg2 "$config $config_time"
	
	# Check if $config needs to be updated by checking the modification time of each file in the list
	if [[ $update -eq 0 ]]; then 
		for file in ${configs[@]}; do
			mod_time=$(stat -c %Y "$file")
			dbg2 "$file $mod_time"
			if [ "$mod_time" -gt "$config_time" ]; then
				update=1
			fi
		done
	fi
	
	# If any sub-config is newer than $config, update $config
	if [[ $update -eq 1 ]]; then
		dbg "Backup $config"
		backup "$config"
		dbg "Updating $config with the content of all sub-configs..."
		printf "## DO NOT MODIFY THIS FILE. 
## IT WILL BE OVERWRITTEN BY getVar.sh AS SOON AS THE NON-HIDDEN CONFIG-FILES ARE MODIFIED.
## APPLY MODIFICATIONS IN THE CORRSPONDING SUB-CONFIG FILE.
## LAST UPDATE: $(date)" > "$config"
		# As fsdb.config defines very basic variables it needs special treatment: always first in $config.
		restructureConfig "$fsdbconfig" >> "$config" 
		# Add the contents of the other config-files (with the exception of $fsdbconfig
		for file in $( ls ${configs[@]} |grep -v "${fsdbconfig}"); do
			dbg2 "updating $config with $file"
			restructureConfig "${file}" >> "$config"
		done
		# making backup of modified configuration.	
		backup "$config"
		
	else
		dbg2 "No configs have been modified since $config was last updated."
	fi
}

function restructureConfig(){
# transformes the key-value pairs of the individual sub-configurations into 
# triplets of key-category-value ( separated by space-pipe-space) and writes 
# them (under the corresponding headline) into .scripts.config
	printf "\n\n# ==> Modify values below in ${1} <==\n"
	
	bn=$(basename "$1" .config)
	
# make sure all sub-configs end on an empty line
	lastline=$(tail -1 "$1")
	if [[ "$lastline" != "" ]]; then 
		printf "\n" >> "$1"
	fi

	while read -r line; do
			if [[ $(echo "$line" |grep -c '^\#.*$') -gt 0 || -z $line ]];then
					echo "$line"
			else
					key=$(echo "$line" |cut -d " " -f 1)
					value=$(echo "$line" |cut -d " " -f 2- |sed 's@\#.*@@')
					printf "$key | $bn | $value\n"
			fi
	done < "$1"	
}

function backup() {
# This function creates a dated and numbered backup of the input file 
	if [[ -n ${2:-} && -d $2 ]]; then
		bupdir=$(realpath "$2") #TODO: restructure to get rid of the $2
	else
		bupdir="$(dirname "$(realpath "$1")")"
	fi
	bup="$(basename "$1")"
	counter=0
	bf="${bupdir}/${bup}.bup${D}"
	while [[ -f "$bf" ]]; do
			counter=$((counter+1))
			bf=${bupdir}/${bup}.bup${D}-$counter
			dbg2 "$bf"
	done
	cp "$1" "$bf"
	dbg "Backup of $1 written to $bf ."
}


function makeDirs() {
# create default directories as defined in .scripts.config
	for defaultdir in $(cut -d " " -f 1 "$config" |grep -v "#" |grep DIR$ |sort -u); do
		path=$(grep "^$defaultdir " "$config" |awk -F "|" '{print $NF}'|cut -d " " -f 2 |sed -e 's@\t.*@@' -e 's@#.*@@')
		defaultpath="$(eval echo "$path" |tail -1)"
		mkdir -pv "$defaultpath" >> "$LOG" 2>&1
		dbg2 "${defaultdir}: ${path}: $defaultpath"
		chown -R "$ADMIN":"$GROUP" "$defaultpath" >> "$LOG" 2>&1
		chmod -R 770 "$defaultpath" >> "$LOG" 2>&1
		export "${defaultdir}=${defaultpath}"
	done
}

function sudoer() {
## ROOT PRIVILEDGES
# Because for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
	if [ "$(whoami)" != "root" ]; then 
		error "This script needs to be run with root privileges."
		exit 1
	fi
}

## ======
## FUNCTION CALLS
## ======

# make sure, that the sourcing script is run as superuser/root
sudoer

#debug=2


# define SCRIPTSDIR and FSDBDIR, which is the root of the fsdb, 
# dynamically on the basis of the location of this script
if [[ "$getVarDir" =~ /fsdb[0-9]{2}/ ]]; then
	SCRIPTSDIR="$(realpath $getVarDir |sed -r 's@(/scripts/).*@\1@')"
else
	SCRIPTSDIR="$(realpath "$getVarDir/..")"
fi
if [[ "$getVarDir" =~ /fsdb[0-9]{2}/ ]]; then
	FSDBDIR="$(realpath $getVarDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
else
	FSDBDIR="$(realpath $getVarDir/../../..)"
fi
# Define central configuration file.
config="$(realpath "$SCRIPTSDIR/.scripts.config")"
#config=$(find $(realpath $SCRIPTSDIR) -type f -name ".scripts.config")

# Define configuration file of the fsedb. This defines/dictates the structure of the fsdb. 
fsdbconfig="$(realpath "$SCRIPTSDIR/fsdb.config")"
#fsdbconfig=$(find $(realpath $SCRIPTSDIR) -type f -name "fsdb.config")

# timestamp for index files
D=$(date +%y%m%d)
# define 'D' (timestamp) centrally
export "D=$(echo $D)"
# for processes, which may run longer than a day, 
# (and by that will change D),
# define a fixed STARTDATE.
# This will be set at the first run only.
if [[ -z ${STARTDATE:-} ]]; then
	export "STARTDATE=$D"
fi

# check, if $config exists and is up-to-date
checkConfig "${1:-}"

# export directories defined above
dbg2 "SCRIPTSDIR = $SCRIPTSDIR"
export "SCRIPTSDIR=$(eval echo "$SCRIPTSDIR")"
dbg2 "FSDBDIR = $FSDBDIR"
export "FSDBDIR=$(eval echo "$FSDBDIR")"

# for each element in the first column of .scripts.config 
# export all following values as content of the variable 
# with the name of the element in the first column.
#for i in $(cut -d " " -f 1 "$config" |grep -v "#" |sort -u); do
for i in $(cut -d " " -f 1 "$config" |grep -v "#"); do
	#echo $i
	d="$(grep "^$i " "$config" |sort)"
	if [[ $(grep -c "^$i " "$config") -gt 1 ]]; then
		warn "multiple instances of $i:\n$d"
		d="$(grep "^$i " "$config" |sort |tail -1)"
		warn "keeping $d"
	fi
	dbg2 "$d"
	if [[ $(echo "$d" |grep -c "|" ) -eq 0 ]]; then #check for existence of a category (e.g., |cat|)
		# the outer subshell is needed for expanding variables within the read-in values
		#export "$i=$(eval echo $(echo "$d" |cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@') |awk '{print $1}')"
		export "$i=$(eval echo $(echo "$d" |cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@'))"
	else
		#export "$i=$(eval echo $(echo "$d" |awk -F "|" '{print $NF}'|cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@' |awk '{print $1}'))"
		export "$i=$(eval echo $(echo "$d" |awk -F "|" '{print $NF}'|cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@'))"
	fi
	dbg2 "getVar: $i = ${!i}"
done

dbg "global debug level: ${DEBUGLEVEL:-1}"

# Machine-specific processing limits are isolated in a testable helper. Use
# the short hostname so local DNS configuration cannot change profile matching.
setMachineProfile "$(hostname -s 2>/dev/null || hostname)"

# FIJIONSERVER may be supplied by a module configuration. An empty value is a
# valid indication that no machine-specific override has been configured.
export FIJIONSERVER="${FIJIONSERVER:-}"

# log file for debugging and cleanup
mkdir -p "$LOGDIR"
LOG="$LOGDIR/$D.$(basename "$0" .sh).log"
dbg "logs at $LOG"
#if [ -f $LOG ]; then
#	sudo rm $LOG
#fi
date >> "$LOG"
export "LOG=$LOG"

# make sure, that all default directories (as defined in .scripts.config) exist
makeDirs
