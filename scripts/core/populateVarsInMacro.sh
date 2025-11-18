#!/bin/bash
#fsdb-rev-date: 240310 <-- OK
#============================
# define variables and generate directories as needed
#============================
# get location of this script
thisDir=$(dirname $(realpath "$0"))

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

if [[ ! -f $1 ]];then
	error "missing macro as first parameter. Exiting."
	exit
else
	macro=$1
	init=$INITFSDB_FMAC
fi

msg "populating variables in $macro"
dbg "populating variables in $macro"

dbg2 "$POPVARS_FUN"


#macro=/mnt/c/Users/teforadmin/tps/gitlab/fusion/fsdb23/scripts/ants-reg/Fiji.app/macros/fsdb.ant-reg/wrapper.ijm
#init= /mnt/c/Users/teforadmin/tps/gitlab/fusion/fsdb23/scripts/Fiji.app/macros/fsdb.core/fsdb.core.initFsdb.ijm
#vars=$(echo $macro |sed 's@.ijm@.vars.ijm@')
vars=$(echo $macro |awk -F "." '{print $1".vars"}')
avs=//FSDBAUTOVAR

dbg2 "$(ls -l $macro)" #<-- for debugging only
dbg2 "$(ls -l $init)" #<-- for debugging only
if 	[[ ! -f $init ]]; then
	bash $MAKEFSDBINIT
fi


dbg2 "$(ls -l $POPVARS_FUN)" #<-- for debugging only

if [[ ! -f $POPVARS_FUN ]]; then
# This creates the file $POPVARS_FUN
	dbg "creating $POPVARS_FUN" 
	printf "function getFsdbVars(){
// These functions search and run INITFSDB_FMAC, which reads in and populates 
// all ij.Prefs defined in .scripts.config of the fsdb
// In case it can not find INITFSDB_FMAC (e.g., if this macro is run outside of
// a fsdb installation), it will demand input from the user. 
//# the 8 backslashes in the next line are necessary to have two left-over in the macro
	INITFSDB_FMAC=replace(FIJIDIR+\"/macros/fsdb.core/fsdb.core.initFsdb.ijm\", \"\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\", \"/\");
	if (File.exists(INITFSDB_FMAC) == 0){
			getFsdbDir();
		}
	print(INITFSDB_FMAC);
	runMacro(INITFSDB_FMAC);
}

function getFsdbDir(){
	FSDBDIR=getDirectory(\"Unclear installation; please select the directory of your fsdb-installation\");
//# the 8 backslashes in the next line are necessary to have two left-over in the macro
	FSDBDIR=replace(FSDBDIR,\"\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\",\"/\");
	TMP=FSDBDIR+\"scripts/Fiji.app/\";
	if(File.isDirectory(TMP)){
		FIJIDIR=TMP;
		debugger(\"success\", LOG);
		INITFSDB_FMAC=FIJIDIR+\"/macros/fsdb.core/fsdb.core.initFsdb.ijm\";
	} else {
		waitForUser(\"ERROR: input invalid.\", FSDBDIR+\" does not appear to be a vaild fsdb-installation.\\\\n(couldn't find \"+TMP+\").\\\\nPlease hit OK and try again.\" );
		getFsdbDir(); 
	}
}

//# !!! ensure that this call is always in the last line of this file!!!
// get all varables defined in the .scripts.config of the fsdb
if (getInfo(\"os.name\") == \"Linux\"){
	FIJIDIR=getDirectory(\"imagej\");
} else {
	FIJIDIR=File.getDirectory(getInfo(\"ij.executable\"));
}
print(\"FIJIDIR: \"+FIJIDIR);
getFsdbVars();
" > $POPVARS_FUN
else
	dbg "$POPVARS_FUN exists."
fi

# integrate function 'getFsdbVars' and helper function 'getFsdbDir' as well as 
# call of 'getFsdbVars' on top of macro to update the 'ij.Prefs' before querying
# them.
# All imported lines end on $avs; so they can be recognized in future runs.
funCall=$(cat $POPVARS_FUN |grep -v -e '^[[:space:]]*$' |tail -1)
dbg2 $funCall #<-- for debugging only
#if [[ $(grep -v ${avs} $macro |grep -c "$funCall" ) -eq 0 ]]; then
if [[ $(grep -c "$funCall" $macro) -eq 0 ]]; then
# print header warning into temporary file vars	
	printf "${avs}
// !!! DO NOT EDIT THE LINES ENDING ON ${avs}\t\t\t${avs}
// THESE WILL BE REPLACED/EDITED AUTOMATICALLY BY THE FSDB.\t\t${avs}
// USE THE CONFIGURATION FILES TO MODIFY THESE ENTRIES.\t\t\t${avs}\n" > $vars

# copy active (not-commented) code from POPVARS_FUN to top of temporary file vars
# 'read' motivated by https://stackoverflow.com/a/37797456/5269099
	while read; do 
		if [[ $(echo "${REPLY}" |wc -m) -gt 1 ]];then
			printf "${REPLY}\t$avs\n" |grep -v -e '^//#'
		fi
	done < $POPVARS_FUN >> $vars

	
# debugging echo. 	
	if [[ debug -ge 2 ]]; then #<-- for debugging only
		grep -v ${avs} $macro |grep -wo [A-Z][A-Z_]*[A-Z] |sort -u |grep -v -e COMP -e FIJIDIR -e FIJIONSERVER -e LOG -e MACROSDIR -e ORDER -e README -e SCRIPTSDIR -e STARTDATE -e WORKDIR
	fi

# make a copy of the macro. preexisting vars from the fsdb-name-space will be 
# commented out and replaced by the value defined in .scripts.config  	
	modmac=$(echo $macro |sed 's@ijm@mod@')
	cp $macro $modmac

	#grep -wo [A-Z][A-Z_]*[A-Z] $macro |grep -v ${avs} |sort -u|while read i; do 
	grep -v ${avs} $macro |grep -wo [A-Z][A-Z_]*[A-Z] |sort -u|while read i; do 
		#echo; 
		dbg2 "i: $i"; #<-- for debugging only
		grep --color -w $i $init |grep call \
		|grep -v LOG \
		|grep -v README \
		|grep -v DEPRECATED \
		|grep -v ARCHIVEDIR \
		|grep -v ATTICDIR \
		|grep -v DUMPDIR \
		|grep -v EXCHANGEDIR \
		|grep -v EXPORTDIR \
		|grep -v LABDIR \
		|grep -v PROJECTDIR \
		|grep -v STORAGEDIR \
		|sort -u \
		|while read j; do
			dbg2 "j: $j" #<-- for debugging only
			vn=$(echo $j |awk '{print $NF}')
			sed -i "s@${vn}=@//&@" $modmac
			printf "${vn}=${j} $avs\n" |sed 's@ij.Prefs.set@ij.Prefs.get@'  >> $vars
		done 
	done 
	echo $avs >> $vars
	
# combine the temporary files vars and modmac 	
	grep -v $avs $modmac >>$vars
	mv $macro ${macro}.bup
	mv $vars $macro	
	rm $modmac 
else
	warn "$macro already has ${funCall}. Skipping."
fi

msg "vars populated in $macro"
dbg "vars populated in $macro"
