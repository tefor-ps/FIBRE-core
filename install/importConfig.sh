#!/bin/bash
<<README
This script is importing (newer) config files into the given fsdb-instance.

The config-files are acquired from a git-repo with the name \$(basename [input instance of fsdb])-configs. 
This repo is cloned pr pulled into a directory with the same name, next to the fsdb-instance.
Subseqently the config files are copied into the fsdb-instance using rsync.

This script shall NOT be run as super-user.

README

# fsdb revision 251023

function fail(){
	#intro "$@"
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

# cyan text on black background to introduce the current script or say something important
intro() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[36;1m'"$@"$'\e[0m\n'; else echo "$@"; fi >&2 ;}

# error message; white on red background
error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}

if [[ "$(whoami)" != "root" ]]; then
	fail "This script must be run as super-user."
	#exit 1
fi

if [[ -z $1 ]]; then
	fail "Please provide target directory as parameter."
	#exit
else
	mkdir -pv "$1" 
	fsdbDir=$(realpath "$1")
fi

td=$(realpath "$(dirname $0)")

fsdbroot=$(basename "$fsdbDir")
#echo $fsdbroot
if [[ "$fsdbroot" =~ "fsdb" ]]; then
	configsdir=$(realpath "${fsdbDir}/../${fsdbroot}-configs/")
	intro "Importing configs into $configsdir"	
	#repo=git@gitlab.com:arnimjenett/${fsdbroot}-configs.git
	repo=https://gitlab.com/arnimjenett/${fsdbroot}-configs.git
else
	fail "$fsdbDir doesn't appear to be a fsdb-root directory (fsdb*)."
	#exit
fi

# https://stackoverflow.com/a/226724
while true; do 
    read -p "Do you wish to get configs from ${repo}? [Y/n]: " -i "Y" -e ans
    case $ans in
        [Yy]* ) getrepo=1; break;;
        [Nn]* ) getrepo=0; break;;
        * ) intro "Please answer yes or no.";;
    esac
done

# check user input
if [[ ! -d $fsdbDir ]]; then
	fail "Provide the path to the fsdb-instance you want to import the configs to."
	#exit
else
	intro "Importing configs from $configsdir to $fsdbDir"

# get latest versions from gitlab repo
	if [[ $getrepo -eq 1 ]]; then
		if [[ ! -d "$configsdir" ]]; then
			cd "$fsdbDir/.." || fail
			git clone $repo || fail
		else
			cd "$configsdir" || fail
			git pull || fail
		fi
	fi

	if [[ -d "$configsdir" ]]; then
# make directories and transfer config files into correct locations 
		find "$configsdir" -name "*.config*" |grep -v "~" |sed 's@^./@@'|while read i; do
			od=$(dirname "$i" |sed "s@${configsdir}@${fsdbDir}/@")
			echo "$(realpath $i) --> $od"
			mkdir -pv "$od"
			if [[ "$2" == "force" ]]; then
				#intro "overwrite $od with $i"
				rsync -Sa "$i" "$od"
			else
				#intro "update $od with $i"
				rsync -Sau "$i" "$od"
			fi
		done
		modFSDBCONFIG=$(find $configsdir -type f -name fsdb.config |grep -v template |tail -1)
		intro "$(basename $0):modFSDBCONFIG: $modFSDBCONFIG"
		export modFSDBCONFIG=$modFSDBCONFIG
	else
		fail "Can't find ${configsdir}."
	fi
fi
