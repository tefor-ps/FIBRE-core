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

The global debugging level is defined by the first parameter to the sourcing of 
 fun_colMsg.sh
The local debugging level is set (for each script individually) by the variable 
 'debug', which also can have the same values as the global levels (0-3)
	
Aside of ALL VARIABLES DEFINED IN .scripts.config this script explicitly exports/
populates the following variables:
- D : timestamp of today in YYMMDD
- STARTDATE : same as $D but in contrast to $D this will not be updated at midnight. 
	STARTDATE is used to keep referencing the $INDEX of the starting day even 
	if/while the process is running longer than midnight.
- SCRIPTSDIR : directory, which is containing all (shell) scripts of the fsdb.
- WORKDIR : the root-directory of the fsdb

--> machine-specific configurations
- COMP : name of the computer this script is running on 
- maxsize : maximal file size that can be handled on this machine
- minsize : minimal filesize to b handled by this machine
- ORDER : sorted order of file list 
	(by default youngest first('age'), on big machines biggst first ('size'))
- FIJIONSERVER : potentially overwrites which script is used to run the 
	secData-Generator

README
#fsdb-rev-date: 230922

## ======
## FUNCTION DEFINITIONS
## ======

function checkConfig(){
	# detect missing configuration file and create one from template, if needed.
	if [[ ! -f $config || ! -f $fsdbconfig ]]; then 
		intro "Welcome to the fsdb-setup.
	It appears, that you didn't set up the configuration of the system, yet.
	Since this is necessary for the correct installation of the fsdb, 
	it is strongly recommended to do this right now."
		makeConfig
	else
	# reconfigure pre-existing installation, if demanded by passing parameter 'config' to getVar 
		if  [[ "$1" == "config" ]]; then
			intro "Welcome to the reconfiguration of an existing fsdb-installation
	In the following you can change the configuration and layout of your fsdb-installation or create a completely new one."
			cat $fsdbconfig
			warn "$config already exists."
			backup $config
			skipRest "Above you find the contents of your current fsdb.config.\nDo you want to reset it to default values." resetConfig
			editConfig
		fi
	# update scripts.config, if needed.
		updateConfig
	fi
}

function makeConfig() {
# This function creates a new configuration file on the basis of the provided 
# default configuration and allows the user to modify it
	if [[ ! -f $fsdbconfig ]]; then
		resetConfig
	else
		ONLINEDOC=$(grep "^ONLINEDOC " $fsdbconfig |cut -d " " -f 2) #TODO: $ONLINEDOC is the URL of the repo at gitlab. 
		# This is intended to open/access the online documentation (in the default browser) but is not at all implemented, yet. 
		# See https://stackoverflow.com/a/38147878/5269099
		backup $fsdbconfig
	fi
	cat $fsdbconfig
	echo
	skipPerm "Above you find the content of your $fsdbconfig. Preparing editor.\nThe next step will give you the opportunity to edit a preformatted fsdb.config file in you default text editor.\nFor details on this please refer to the README at this project's gitlab page:\n$ONLINEDOC" editor $fsdbconfig
	updateConfig
# making backup of modified configuration.	
	backup $config 
}

function resetConfig(){
#	fcd=$getVarDir/../install/templates/fsdb.config.default
	fcd=$(find $getVarDir/../../ -name "fsdb.config.default")
	cp $fcd $fsdbconfig
	ONLINEDOC=$(grep "^ONLINEDOC " $fcd |cut -d " " -f 2)
}

function editConfig(){
	skipPerm "Do you want to modify your fsdb.config?\n" editor $fsdbconfig
	intro "Below you find the content of your new $fsdbconfig\n"
	cat $fsdbconfig
}

function updateConfig(){
	# List of configs to compare.  
#	configs=$(find $(realpath $CONFIGDIR) -name "*.config" |grep -v $config )
	localConfigs=$(find $(realpath $CONFIGDIR) -name "*.config" |grep -v $config )
	dbg2 "localConfigs at $(realpath $CONFIGDIR)\n$(ls -l ${localConfigs[@]})"

	moduleConfigs=$(find $(realpath $thisDir) -name "*.config" |grep -v $config )
	dbg2 "moduleConfigs at ${thisDir}\n$(ls -l ${moduleConfigs[@]})"

	configs=("${localConfigs[@]}" "${moduleConfigs[@]}")
	dbg2 "all configs\n$(ls -l ${configs[@]})"
	
	# Check if $config exists, if not create it
	if [ ! -f $config ]; then
		touch $config
		update=1
	else
	# Set a flag to indicate whether $config needs to be updated (default: no update)
		update=0
	fi
	
	# Get the modification time of $config
	config_time=$(stat -c %Y $config)
	dbg2 "$config $config_time"
	
	# Check if $config needs to be updated by checking the modification time of each file in the list
	if [[ $update -eq 0 ]]; then 
		for file in ${configs[@]}; do
			mod_time=$(stat -c %Y $file)
			dbg2 "$file $mod_time"
			if [ "$mod_time" -gt "$config_time" ]; then
				update=1
			fi
		done
	fi
	
	# If any sub-config is newer than $config, update $config
	if [[ $update -eq 1 ]]; then
		dbg "Updating $config with the content of all sub-configs..."
		backup $config
		printf "## DO NOT MODIFY THIS FILE. 
## IT WILL BE OVERWRITTEN BY getVar.sh AS SOON AS THE NON-HIDDEN CONFIG-FILES ARE MODIFIED.
## APPLY MODIFICATIONS IN THE CORRSPONDING SUB-CONFIG FILE.
## LAST UPDATE: $(date)" > $config
		# As fsdb.config defines very basic variables it needs special treatment: always first in $config.
		restructureConfig $fsdbconfig >> $config 
		# Add the contents of the other config-files (with the exception of $fsdbconfig
		for file in $( ls ${configs[@]} |grep -v ${fsdbconfig}); do
			restructureConfig ${file}
		done >> $config
	else
		dbg2 "No configs have been modified since $config was last updated."
	fi
}

function restructureConfig(){
# transformes the key-value pairs of the individual sub-configurations into 
# triplets of key-category-value ( separated by space-pipe-space) and writes 
# them (under the corresponding headline) into .scripts.config
	printf "\n\n# ==> Modify values below in ${1} <==\n"
	
	bn=$(basename $1 .config)
	
# make sure all sub-configs end on an empty line
	lastline=$(tail -1 $1)
	if [[ "$lastline" != "" ]]; then 
		printf "\n" >> $1
	fi

	while read line; do
			if [[ $(echo "$line" |grep -c '^\#.*$') -gt 0 || -z $line ]];then
					echo $line
			else
					key=$(echo $line |cut -d " " -f 1)
					value=$(echo $line |cut -d " " -f 2- |sed 's@\#.*@@')
					printf "$key | $bn | $value\n"
			fi
	done < $1	
}

sudoer() {
## ROOT PRIVILEDGES
# Because for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
if [ $(whoami) != "root" ]; then 
	error "WARNING: This script needs to be run with root-priviledges."
	exit
fi
}

function backup() {
# This function creates a dated and numbered backup of the input file 
		if [[ -d $2 ]]; then 
			bupdir=$(realpath $2) #TODO: restructure to get rid of the $2
		else
			bupdir=$(dirname $(realpath $1))
		fi
        bup=$(basename $1)
        counter=0
        bf=${bupdir}/${bup}.bup${D}
        while [[ -f $bf ]]; do
                counter=$[counter+1]
                bf=${bupdir}/${bup}.bup${D}-$counter
                dbg2 $bf
        done
        cp $1 $bf
        dbg "Backup of $1 written to $bf ."
}


function makeDirs() {
# create default directories as defined in .scripts.config
	for defaultdir in $(cut -d " " -f 1 $config |grep -v "#" |grep DIR$); do
		path=$(grep "^$defaultdir " $config |awk -F "|" '{print $NF}'|cut -d " " -f 2 |sed -e 's@\t.*@@' -e 's@#.*@@')
		#dbg2 "$(eval echo $path)"
		mkdir -pv $(eval echo $path) >>$LOG 2>&1
		chown $ADMIN:$GROUP $(eval echo $path) >>$LOG 2>&1
		chmod 770 $(eval echo $path) >>$LOG 2>&1
	done
}

sudoer() {
## ROOT PRIVILEDGES
# Because for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
	if [ $(whoami) != "root" ]; then 
		printf $'\r\e[2K\t\e[31;1;40m'"WARNING: This script needs to be run with root-priviledges."$'\e[0m\n' 
		exit
	fi
}

## ======
## FUNCTION CALLS
## ======

# make sure, that the sourcing script is run as superuser/root
sudoer

#debug=2

getVarDir=$(realpath $(dirname $BASH_SOURCE))
CONFIGDIR=$getVarDir/..
config=$(realpath $CONFIGDIR/.scripts.config)
#config=$(find $(realpath $CONFIGDIR) -name ".scripts.config")
fsdbconfig=$(realpath $CONFIGDIR/fsdb.config)
#fsdbconfig=$(find $(realpath $CONFIGDIR) -name "fsdb.config")
#GVconf=$getVarDir/.gv.config #TODO: implement this for the export of getVar-variables to fiji
#rm $GVconf

# the global debug level is set as parameter to fun_colMsg (0-2; default 1)
source $getVarDir/fun_colMsg.sh $DEBUGLEVEL

# timestamp for index files
D=$(date +%y%m%d)
# define 'D' (timestamp) centally
export "D=$(echo $D)"
#echo "D $D" |tee -a $GVconf
# for processes, which may run longer than a day 
# (and by that will change D)
# define a fixed STARTDATE. 
# This will be set at the first run only.
if [ -z $STARTDATE ]; then 
	export "STARTDATE=$(echo $D)"
	#echo "STARTDATE $D" |tee -a $GVconf
fi

# check, if $config exists and is up-to-date
checkConfig $@

# define WORKDIR, which is the root of the fsdb, dynamically on the basis of the 
# location of this script
td=$(realpath $getVarDir/..)
dbg2 "SCRIPTSDIR = $td"
export "SCRIPTSDIR=$(eval echo $td)"
#echo "SCRIPTSDIR $td" |tee -a $GVconf
td=$(realpath $SCRIPTSDIR/..)
export "WORKDIR=$(eval echo $td)"
#echo "WORKDIR $td" |tee -a $GVconf
# define Fiji directories
fd=$(grep FIJIDIR $config  |grep -v ^# |awk -F "|" '{print $NF}'|cut -d " " -f 2|cut -f 1)
dbg2 "FIJIDIR = $(eval echo $fd)"
export "FIJIDIR=$(eval echo $fd)"
#echo "FIJIDIR $fd" |tee -a $GVconf
export "MACROSDIR=$(eval echo $FIJIDIR/macros)"
#echo "MACROSDIR $FIJIDIR/macros" |tee -a $GVconf

# for each element in the first column of .scripts.config 
# export all following values as content of the variable 
# with the name of the element in the first column.
for i in $(cut -d " " -f 1 $config |grep -v "#"); do
#	echo ":getVar:$0: $i"
	d=$(grep "^$i " $config)
   if [[ $(echo $d |grep -c "|" ) -eq 0 ]]; then #check for existence of a category (e.g., |cat|)
      # the outer subshell is needed for expanding variables within the read-in values
      export "$i=$(eval echo $(echo $d |cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@'))"
   else
   	   export "$i=$(eval echo $(echo $d |awk -F "|" '{print $NF}'|cut -d " " -f 2- |sed -e 's@\t.*@@' -e 's@#.*@@' -e 's@^ @@'))"
  fi
  dbg2 "$i = ${!i}" |grep -e "DIR "
done

dbg "global debug level: $DEBUGLEVEL"

# machine-specific configurations, 
case $(hostname) in
	Monster)
		COMP="monster"
#		14GB =	14771089024
		maxsize=250000000000	#250GB @ 512GB RAM --> process everything
		minsize=100000000		#--> process everything bigger than 100MB
		ORDER="size"
#		ORDER="age"
#		FIJIONSERVER=fijiOnMonster.sh
		;;
	PWE-T630-TEFOR-2)
		COMP="beast"
#       14GB =  14771089024
		maxsize=250000000000    #250GB @ 512GB RAM --> process everything
		minsize=1000000000      #--> process everything bigger than 1GB
		ORDER="size"
#       ORDER="age"
		#FIJIONSERVER=fijiOnMonster.sh
		;;
	celph-gif)
		COMP="celph-gif"
#		14GB =	14771089024
		maxsize=6000000000 	    #6GB @16GB RAM
		minsize=1000000         #--> process everything bigger than 1MB
		ORDER="size"
#		ORDER="age"
		;;
	tefor-gif)
		COMP="tefor-gif"
#		14GB =	14771089024
		maxsize=20000000000     #20GB @62GB RAM
		minsize=1000000         #--> process everything bigger than 1MB
		ORDER="age"
		;;
	celph-lyon)
		COMP="celph-lyon"
#		14GB =	14771089024
		maxsize=6000000000      #6GB @16GB RAM
		minsize=1000000         #--> process everything bigger than 1MB
		ORDER="size"
		;;
	*)
		COMP=$(hostname)
#		14GB =	14771089024
		maxsize=4000000000      #4GB
		minsize=1000000         #--> process everything bigger than 1MB
		ORDER="age"
		;;
esac
dbg2 "getVar: $COMP $ORDER"
export "COMP=$(echo $COMP)"
#echo "COMP $COMP" |tee -a $GVconf
export "maxsize=$maxsize"
export "minsize=$minsize"
export "ORDER=$ORDER"
#echo "ORDER $ORDER" |tee -a $GVconf
export "FIJIONSERVER=$FIJIONSERVER"
#echo "FIJIONSERVER $FIJIONSERVER" 

# log file for debugging and cleanup
mkdir -p $LOGDIR
LOG="$LOGDIR/$D.$(basename $0 .sh).log"
dbg "logs at $LOG"
#if [ -f $LOG ]; then
#	sudo rm $LOG
#fi
date >> $LOG
export "LOG=$LOG"

# make sure, that all default directories (as defined in .scripts.config) exist
makeDirs
