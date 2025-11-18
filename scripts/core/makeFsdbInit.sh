#!/bin/bash
<<README
This script translates the label-value-pairs of .scripts.config into ij.Prefs
by creating the macro INITFSDB_FMAC (fsdb.core.initFSDB.ijm) in the COREMACROS directory. 

The INITFSDB_FMAC is used by the macros of the fsdb to read-in the values of .scripts.config.

README
#fsdb-rev-date: 2401119 <-- OK


#============================
# FUNCTION DEFINITIONS
#============================
function getModeCoreCat(){
	CORE=$(echo $1 |awk -F "_" '{print $1}')
	if [[ "$CORE" =~ ^"STACK" ]]; then
		core=$(echo $CORE |sed 's@STACK@@'|tr '[:upper:]' '[:lower:]');
	else
		core=$(echo $CORE |tr '[:upper:]' '[:lower:]')
	fi
	cat=""
	cat=$(eval echo $(grep ^$1 $CONFIG |awk -F "|" '{print $2}' |tail -1 ))
	#echo "$1 $cat"
	if [[ -z $cat ]]; then 
		cat=.fsdb
	else
		cat=.${cat}		
	fi
}

usage() {
	printf "Usage: $(basename $0) [-f] [-h] [-p project]  
				
	-f	force creation of INITFSDB_FMAC
			Recreates INITFSDB_FMAC not matter what age.

	-h	help
			Displays this help.


" 1>&2;
	exit 1;
}

#============================
# define variables and generate directories as needed
#============================
# get location of this script
thisDir=$(dirname $(realpath "$0"))

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

SCRIPT=~/tmp
cat=""
base="fsdb"
FORCEINDEX=0

# get parameters/options passed at call of this script
while getopts ":p:fh" opt; do
	case $opt in
		f)
			guardian $OPTARG
			dbg2 "Option -f was triggered, this will force index generation"
			FORCEINDEX=1
			FSTRING="-f"
			;;
		h)
			usage
			;;
		\?)
			error "Invalid option: -$OPTARG" 
			exit 1
			;;
		:)
			error "Option -$OPTARG requires an argument." 
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

dbg2 "INITFSDB_FMAC newer than $permissibleAgeOfIndex: $(find $INITFSDB_FMAC -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2>/dev/null |wc -l)"
dbg2 "FORCEINDEX: $FORCEINDEX"
#exit 1

if [[ $(find $INITFSDB_FMAC -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2>/dev/null |wc -l) -eq 0 ]] || [[ $FORCEINDEX -eq 1 ]];  then
	
	printf "// created " > $SCRIPT
	date >> $SCRIPT
	
	for MODE in $(cut -d " " -f 1 $CONFIG |grep _ |awk -F "_" '{print $2}' |sort -u |grep -v ^FS); do
		dbg2 $MODE 
		printf "// set values for $MODE\n" >> $SCRIPT
		for i in $(grep _$MODE $CONFIG |grep -v ^# |cut -d " " -f 1 |sort -u) ; do
			mode=$(echo $MODE |tr '[:upper:]' '[:lower:]')
			getModeCoreCat $i
			dbg3 "$i - $cat.$mode.$core"
			printf "call(\"ij.Prefs.set\", \"$base$cat.$mode.$core\", \""${!i}"\"); // $i \n" >> $SCRIPT
		done
	done 
	
	printf "// set values for DIR\n"  >> $SCRIPT
	for DIR in $(grep "DIR " $CONFIG |grep -v ^# |cut -d " " -f 1) ; do
		dbg2 $DIR
		dir=$(echo $DIR |tr '[:upper:]' '[:lower:]')
		mode=dir
		getModeCoreCat $DIR
		printf "call(\"ij.Prefs.set\", \"$base$cat.$mode.$core\", \""${!DIR}"\"); // $DIR \n" >> $SCRIPT
	done
	
	printf "// set values for STACK...\n"  >> $SCRIPT
	for STACK in $(grep ^STACK $CONFIG |grep -v ^# |cut -d " " -f 1); do 
		dbg2 $STACK; 
		c=0; 
		#cat=.core; 
		mode=stack; 
		#core=$(echo $STACK |sed 's@STACK@@'|tr '[:upper:]' '[:lower:]'); 
		getModeCoreCat $STACK
		for item in $(grep $STACK $CONFIG |sed 's@#.*@@'|cut -d "|" -f 3-);do 
			#echo $base$cat.$mode.$core.$c $item; 
			printf "call(\"ij.Prefs.set\", \"$base$cat.$mode.$core.$c\", \""${item}"\"); // $STACK.$c \n" >> $SCRIPT
			c=$((c+1)); 
		done
	done
	
	printf "// set values for MACROS\n"  >> $SCRIPT
	for MACRODIR in $(grep "MACROS " $CONFIG |grep -v ^# |cut -d " " -f 1) ; do
		dbg2 $MACRODIR
		macro=$(echo $MACRODIR |tr '[:upper:]' '[:lower:]')
		mode=dir
		getModeCoreCat $MACRODIR
		printf "call(\"ij.Prefs.set\", \"$base$cat.$mode.$core\", \""${!MACRODIR}"\"); // $MACRODIR \n" >> $SCRIPT
	done 
	
	printf "// set values defined by getVar.sh\n" >> $SCRIPT
	for ITEM in $(grep ^export ${COREDIR}/getVar.sh |cut -d" " -f 2|cut -d "=" -f 1 |grep -v [a-z]|sed 's@"@@g');do
		dbg2 $ITEM
		item=$(echo $ITEM |tr '[:upper:]' '[:lower:]')
		cat=getVar
		mode=static
		printf "call(\"ij.Prefs.set\", \"$base.$cat.$mode.$item\", \""${!ITEM}"\"); // $ITEM \n" >> $SCRIPT
	done
	
	#cat $SCRIPT |sed 's@/mnt/c@C:@g' > $INITFSDB_FMAC
	mkdir -p $(dirname $INITFSDB_FMAC)
	cat $SCRIPT > $INITFSDB_FMAC
	dbg "wrote $INITFSDB_FMAC"
	rm $SCRIPT
	
else	
	msg "$INITFSDB_FMAC already exists. Skipping.\n"
fi