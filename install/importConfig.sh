#!/bin/bash
<<README
This script is importing (newer) config files into the given fsdb-instance.

The config-files are acquired from a git-repo with the name \$(basename [input instance of fsdb])-configs. 
This repo is cloned pr pulled into a directory with the same name, next to the fsdb-instance.
Subseqently the config files are copied into the fsdb-instance using rsync.

This script shall NOT be run as super-user.

README

# fsdb revision 250825

if [[ "$(whoami)" != "root" ]]; then
	echo "ERROR: this script shall NOT be run as super-user. Exiting."
	exit 1
fi

if [[ -z $1 ]]; then
	echo "Please provide target directory as parameter. Exiting."
	exit
else
	mkdir -pv "$1" 
	fsdbDir=$(realpath "$1")
fi

td=$(realpath "$(dirname $0)")

fsdbroot=$(basename "$fsdbDir")
if [[ "$fsdbroot" =~ "fsdb" ]]; then
	echo "importing configs into $fsdbDir"	
	configsdir="${fsdbDir}/../${fsdbroot}-configs/"
	#repo=git@gitlab.com:arnimjenett/${fsdbroot}-configs.git
	repo=https://gitlab.com/arnimjenett/${fsdbroot}-configs.git
else
	echo "$fsdbDir doesn't appear to be a fsdb-root directory (fsdb*). Try again; Exiting."
	exit
fi

# https://stackoverflow.com/a/226724
while true; do 
    read -p "Do you wish to get configs from ${repo}? [Y/n]: " -i "Y" -e ans
    case $ans in
        [Yy]* ) getrepo=1; break;;
        [Nn]* ) getrepo=0; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# check user input
if [[ ! -d $fsdbDir ]]; then
	echo "ERROR: provide the path to the fsdb-instance you want to import the configs to. Exiting."
	exit
else
	echo "Importing configs from $configsdir to $fsdbDir"

# get latest versions from gitlab repo
	if [[ $getrepo -eq 1 ]]; then
		if [[ ! -d "$configsdir" ]]; then
			cd "$fsdbDir/.."
			git clone $repo
		else
			cd "$configsdir" || exit
			git pull
		fi
	fi

	if [[ -d "$configsdir" ]]; then
# make directories and transfer config files into correct locations 
		find "$configsdir" -name "*.config*" |grep -v "~" |sed 's@^./@@'|while read i; do
			od=$(dirname "$i" |sed "s@${configsdir}@${fsdbDir}/@")
			echo "$(realpath $i) --> $od"
			mkdir -pv "$od"
			if [[ "$2" == "force" ]]; then 
				rsync -Sa "$i" "$od"
			else
				rsync -Sau "$i" "$od"
			fi
		done
	else
		echo "Can't find "$configsdir". Exiting."
		exit
	fi
fi
