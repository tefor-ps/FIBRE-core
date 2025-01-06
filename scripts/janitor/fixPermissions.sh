#!/bin/bash
<<README
For making sure, that the files are accessible and protected as intended, this
script is (re-)setting the permissions on the fsdb file system and the contained
files.

This script is part of $CLEANIMPORTS

This scripr accepts one optional parameter: 
[$1] = path to the directory which permissions need to be fixed

underlying concept:
- each original data set has two 'pointers', which earlier were gernerated using 'ln'. 
-- one in $STORAGEDIR/$IMPORTS, the other in $LABDATADIR/$IMPORTS, at the corresponding location.
- data at $LABDATADIR/$IMPORTS are user-writeable (770) and by this endangered by destruction/deletion.
- $STORAGEDIR/$IMPORTS and the data within is read-only and inaccessible for standard users.
- if original data is accidentially removed from $LABDATADIR/$IMPORTS, this script reconstitutes it from $STORAGEDIR/$IMPORTS. 

mode of function:
- set permissions for $LABDATADIR/$IMPORTS/ to 770
- set permissions for $INDEXDIR/ to 770
- set permissions for $STORAGEDIR/$IMPORTS/ to 750
README
#fsdb-rev-date: 230331

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

#debug=0

intro $0

# satisfy prerequisits
which setfacl >/dev/null
if [[ $? -eq 1 ]]; then
	sudo apt -y install acl
fi

function fixPerms() {
	if [[ "$4" == "recursive" ]];then 
		dbg2 "fixing permissions recursively for $dir"
		if [[ $debug -gt 2 ]]; then
			sudo mkdir -vp $dir |tee -a $LOG 2>&1
			sudo chown -vR $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -vR $3 $dir |tee -a $LOG 2>&1
		else 
			sudo mkdir -p $dir |tee -a $LOG 2>&1
			sudo chown -R $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -R $3 $dir |tee -a $LOG 2>&1
		fi
	else
		dbg2 "fixing permissions for $dir"
		if [[ $debug -gt 2 ]]; then
			sudo mkdir -vp $dir |tee -a $LOG 2>&1
			sudo chown -v $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod -v $3 $dir |tee -a $LOG 2>&1
		else 
			sudo mkdir -p $dir |tee -a $LOG 2>&1
			sudo chown $1:$2 $dir |tee -a $LOG 2>&1
			sudo chmod $3 $dir |tee -a $LOG 2>&1
		fi
	fi
}
if [[ -z $1 ]]; then
	# set ownership and permissions on administrative folders (ADMIN-level).
	for dir in $BUPROOT $DUMPDIR $ATTICDIR; do
		fixPerms $ADMIN $ADMIN 700 recursive
	done
	
	# set ownership and permissions on inaccessible folders.
	#	for dir in $DATAROOT $LABDIR; do
	#		fixPerms $ADMIN $GROUP 750
	#	done
	for dir in $INDEXDIR $ARCHIVEDIR; do
	#for dir in $INDEXDIR ; do
		fixPerms $ADMIN $GROUP 750 recursive
	done
	
	
	# set ownership and permissions recursively on accessible directory (GROUP-level)
	for dir in $LABDATADIR/$IMPORTS $EXCHANGEDIR; do
		fixPerms $GROUP $GROUP 770 recursive
	done
	
	# set ownership and permissions recursively on accessible directory (ORGANISATION-level
	for dir in $EXPORTDIR ; do
		fixPerms $GROUP $CONSORTIUM 770 recursive
	done
	
	# reset ownership and permissions on inaccessible folder.
	# this overwrites the permissions of the raw-data, which are the only data sets
	# in both locations to 750, which protects them from accidential deletion.
	for dir in $STORAGEDIR/$IMPORTS; do
		fixPerms $ADMIN $GROUP 750 recursive
		sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
	done
	
	## nice little 'echo's. mainly for interactive usage.
	#tree -pug -L 1 $LABDATADIR/$IMPORTS/
	#tree -pug $DATAROOT
	#tree -pug $WORKDIR
else
	dir=$(realpath $1)
	case "$dir" in
		"$LABDATADIR/$IMPORTS"*)
			fixPerms $GROUP $GROUP 770 recursive
			# now set the permissions of the raw data back to 750 - to prevent their accidential deletion.
			dir=$(echo $dir |sed "s@$LABDATADIR@$STORAGEDIR@")
			fixPerms $ADMIN $GROUP 750 recursive
			sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
			;;
		"$EXCHANGEDIR"*)
			fixPerms $GROUP $GROUP 770 recursive
			;;
		"$INDEXDIR"*)
			fixPerms $ADMIN $GROUP 750 recursive
			;;
		"$ARCHIVEDIR"*)
			fixPerms $ADMIN $GROUP 750 recursive
			;;
		"$BUPROOT"*)
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$DUMPDIR"*)
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$ATTICDIR"*)
			fixPerms $ADMIN $ADMIN 700 recursive
			;;
		"$EXPORTDIR"*)
			fixPerms $GROUP $CONSORTIUM 770 recursive
			;;
		"$STORAGEDIR/$IMPORTS"*)
			fixPerms $ADMIN $GROUP 750 recursive
			sudo setfacl -m g:$GROUP:rx  $dir |tee -a $LOG 2>&1
			;;
		*)
			echo "invalid path, can't fix permission"
			;;
	esac
	ls -l $dir	
fi