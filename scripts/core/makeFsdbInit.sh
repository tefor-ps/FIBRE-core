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

#============================
# define variables and generate directories as needed
#============================
# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

debug=1

SCRIPT=~/tmp
cat=""
base="fsdb"

if [[ $(find $INITFSDB_FMAC -ignore_readdir_race -mmin -$permissibleAgeOfIndex 2>/dev/null |wc -l) -eq 1 ]] && [[ $FORCEINDEX -eq 0 ]];  then
	
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
	
fi