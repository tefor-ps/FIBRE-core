#!/bin/bash
<<README
This iscript is exporting all conguration files of the given fsdb-instance to a 
new directory and exports them to gitlab (if the user allows it to).
The target directory is called "$(basename [input instance of fsdb])-configs" 
and is located next to the root folder of the given fsdb-instance.

This script shall NOT be run as super-user.

README

# fsdb revision 250825

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
	echo "exporting from $(realpath $fsdbDir)"	
	configsdir="${fsdbDir}/../${fsdbroot}-configs/"
	repo=git@gitlab.com:arnimjenett/${fsdbroot}-configs.git
else
	echo "$fsdbDir doesn't appear to be a fsdb-root directory (fsdb*). Try again; Exiting."
	exit
fi

if [[ ! -d $fsdbDir ]]; then
		echo "ERROR: $fsdbDir does not exist. Exiting."
		exit
else
	
	# https://stackoverflow.com/a/226724
	while true; do 
		read -p "Do you wish to get configs from ${repo}? " -i "y" -e ans
		case $ans in
			[Yy]* ) getrepo=1; break;;
			[Nn]* ) getrepo=0; break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	if [[ getrepo -eq 1 ]]; then
		mkdir -p $configsdir
		cd $configsdir 
		if [[ -z $(ls -A $configsdir) ]]; then 
			echo "Cloning $repo to $configsdir"
			git clone $repo
		else
			echo "Pulling $repo to $configsdir"
			git pull
		fi
	fi
	
	echo "Exporting configs from $fsdbDir to $configsdir"
	inst=$(basename $fsdbDir)
#	tmpdir=$tmproot/tools/tps-configs/$inst
#	mkdir -p $tmpdir
	find $fsdbDir -type f -name "*.config*" |grep -v -e bup -e .scripts.config  -e ~$ -e \#|while read line; do
		#echo "--> $line"
		out=$(dirname $line |sed -e "s@$fsdbDir@$configsdir@")
		mkdir -p $(dirname $out) || exit
		echo "$line --> ${out}/"
		rsync -Sau $line ${out}/
	done
fi
tree -s $configsdir
cd $configsdir || exit
git status

if [[ $(ls -la  |grep -c .git) -gt 0 ]]; then
	echo "ready to push configs from $configsdir"
	# https://stackoverflow.com/a/226724
	while true; do 
		read -p "Do you wish to push configs to ${repo}? " -i "y" -e ans
		case $ans in
			[Yy]* ) pushrepo=1; break;;
			[Nn]* ) pushrepo=0; break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	if [[ pushrepo -eq 1 ]]; then
		cd $configsdir
		git add --all
		git commit -am "$(date)"
		git push
	fi
else
	echo "$configsdir is not a git repository."
	echo "Creating a new on at $repo"
	git init --initial-branch=master 
	git remote add origin $repo
	git add .
	git commit -m "Initial commit"
	git push -u origin master
fi