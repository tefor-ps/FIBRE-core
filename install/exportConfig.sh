#!/bin/bash
<<README
This script is exporting all conguration files of the given fsdb-instance to a 
new directory and exports them to gitlab (if the user allows it to).
The target directory is called \$(basename [input instance of fsdb])-configs
and is located next to the root folder of the given fsdb-instance.

This script shall NOT be run as super-user.

To make this work you have to set 'repoBase' to a valid (accessible) git repository.

README

# fsdb revision 251031

# cyan text on black background to introduce the current script or say something important
intro() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[36;1m'"$@"$'\e[0m\n'; else echo "$@"; fi >&2 ;}
# red warning message
warn() { if [[ -t 2 ]] ; then date >> $LOG 2>/dev/null; printf $'\r\e[2K\t\e[31;1;40m'"$(basename $0): $@"$'\e[0m\n' |tee -a $LOG 2>/dev/null; else echo "$@"; fi >&1 ;}
# error message; white on red background
error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}

function fail(){
	warn "$(date)"
	warn "Error in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ "
	warn "Exiting."
	exit 333
}

function exportFiles(){
	out=$(dirname $line |sed -e "s@$fsdbDir@$configsdir@")
	mkdir -p $(dirname $out) || exit
	intro "$(basename $line) --> ${out}/"
	rsync -Sau $line ${out}/
}

repoBase=git@gitlab.com:arnimjenett

if [[ "$(whoami)" == "root" ]]; then
	echo "ERROR: this script shall NOT be run as super-user. Exiting."
	exit 1
fi

if [[ -z $1 ]]; then
	echo "Please provide source directory as parameter. Exiting."
	exit
else
	fsdbDir=$(realpath "$1")
fi

td=$(realpath "$(dirname $0)")

fsdbroot=$(basename "$fsdbDir")
if [[ "$fsdbroot" =~ "fsdb" ]]; then
	configsdir="$(realpath ${fsdbDir}/../${fsdbroot}-configs/)"
	repo=${repoBase}/${fsdbroot}-configs.git
	intro "exporting from $fsdbDir to $configsdir"	
else
	echo "$fsdbDir doesn't appear to be a fsdb-root directory (fsdb*). Try again; Exiting."
	exit
fi

if [[ ! -d $fsdbDir ]]; then
		echo "ERROR: $fsdbDir does not exist. Exiting."
		exit
else
	if [[ ! -d $configsdir ]]; then 
		cd $(dirname $configsdir) 
		echo "Cloning $repo to $configsdir"
		git clone $repo
	else
		cd $configsdir 
		echo "Pulling $repo to $configsdir"
		git config pull.rebase false
		git pull origin master
	fi
	
	echo "Exporting configs from $fsdbDir to $configsdir"
	find $fsdbDir -type f -name "*.config*" |grep -v -e bup -e .scripts.config  -e ~$ -e \#|while read line; do
	#	out=$(dirname $line |sed -e "s@$fsdbDir@$configsdir@")
	#	mkdir -p $(dirname $out) || exit
	#	intro "$(basename $line) --> ${out}/"
	#	rsync -Sau $line ${out}/
		exportFiles
	done
	if [[ $(find $fsdbDir -type d -name "*auth*" |wc -l)( -gt 0 ]]; then
		authDir=$(find $fsdbDir -type d -name "*auth*")
		find $authDir -type f |while read line; do
			exportFiles
		done
	fi
fi
tree -pugs $configsdir
cd $configsdir || exit

if [[ $(ls -la  |grep -c .git) -gt 0 ]]; then
	git add --all
	git status
	echo "ready to push configs from $configsdir"
		cd $configsdir
		git add --all
		git commit -am "$(date)"
		git push
fi
