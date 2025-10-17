#!/bin/bash
<<README
Initialization script for the installation of the file system based database (fsdb).

This script is using the information within the configuration file 
(.scripts.config) for the construction of the fsdb.

PREREQUISITES
This script expects the following steps have been done beforehand, manually.
- install operating system (latest Ubuntu (server) LTS, developed and tested on 24.04 LTS) 
- create RAID [*]
- the computers of the acquisition machines need to be prepared for remote access 
of the storage server (this computer).

steps marked [*] are optional but strongly recommended in this context.

PARAMETERS
This script (optionlally) accepts the installation directory as first and only parameter ($1).

README

#fsdb-rev-date: 250911

#TODO: rework this script: no tmp INITDIR, no git-clone, assume this script comes with its core repo, but (potentially) in tmp location
#TODO: revise README

## ======
## FUNCTION DEFINITIONS
## ======

function fail(){
	#intro "$@"
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

function error() { 
	if [[ -t 2 ]] ; then 
		date >> $LOG; 
		printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG
	else 
		echo "$@"
	fi >&2
}

function sudoer() {
## ROOT PRIVILEGES
# because for the for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
if [ $(whoami) != "root" ]; then 
	fail "This script needs to be run with root-privileges."
fi
}

function installLinuxTools(){
# tools installation 
## composite command using aptitude
	printf "Updating Linux repos. This may take a moment or two.\n"
	apt -qq update
	#apt install -y ${appArr[@]}
	for app in ${appArr[@]}; do
		if [[ $(which $app |wc -l) -eq 0 ]]; then
			apt install -y ${app}
		fi
	done
	sudo apt autoremove --purge
}

function defineScriptsDir() {
	if [[ -z $1 ]]; then
		if [[ -z $SCRIPTSDIR ]]; then
			read -p "User interaction needed: Enter the path to the fsdb scripts directory: " -e SCRIPTSDIR
		else
			read -p "User interaction needed: Enter the path to the fsdb scripts directory: " -i $SCRIPTSDIR -e SCRIPTSDIR
		fi
		touchDir $SCRIPTSDIR $2
		SCRIPTSDIR="$(realpath $(echo "${SCRIPTSDIR}" | sed "s@~@$HOME@"))"
	else
		touchDir $@
		SCRIPTSDIR="$(realpath $(echo "${1}" | sed "s@~@$HOME@"))"
	fi
	# check if 'SCRIPTSDIR' ends on 'scripts'
	if [[ $(basename $SCRIPTSDIR) != "scripts" ]]; then
		error "$SCRIPTSDIR does not end on 'scripts'. Please try again."
		defineScriptsDir
	fi
}

function touchDir() {
	# check if 'SCRIPTSDIR' exists 
	if [[ ! -d $1 ]]; then
		# create 'SCRIPTSDIR' because user set $2 greater than 0
		if [[ $2 -gt 0 ]]; then
			#mkdir -pv $1
			mkdir -p $1
		else
			# ask for permission to create 'SCRIPTSDIR'
			read -p "$1 is not a directory. Do you want to create it? " -i "y" -e ans
			if [[ "$ans" == "y" ]]; then
				#mkdir -pv $1
				mkdir -p $1
			else
				error "Please try again."
				defineScriptsDir
			fi
		fi
	fi	
}

## ======
## FUNCTION CALLS
## ======

# empty terminal
#clear

# confirm root status
sudoer

# list of linux apps to install
#appArr=(nload htop tree vlc samba vim nano gitg meld xvfb libimage-exiftool-perl ffmpeg curl unzip p7zip-full gparted cifs-utils nfs-common rename imagemagick)
#appArr=(tree samba vim nano meld xvfb libimage-exiftool-perl ffmpeg curl unzip cifs-utils nfs-common imagemagick)
appArr=(wget xvfb curl unzip cifs-utils nfs-common imagemagick)


# define FSDBDIR, which is the root of the fsdb dynamically
# on the basis of the location of this script.
# This will be immediatly overwritten/corrected when sourcing getVar.sh
thisDir="$(realpath "$(dirname "$0")")"
if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
	FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
else
	FSDBDIR="$(realpath $thisDir |sed -r 's@/fsdb-core/.*@@')"
fi

# INITDIR is the root directory of the fsdb-installation
# During installation this is a temporary 
INITDIR="$(realpath $thisDir |sed -r 's@/fsdb-core/.*@@')"
repoName=$(ls -ltr "${FSDBDIR}" |tail -1 |awk '{print $NF}')

# set all global variables or at least the ones necessary
GETVAR=$(find "${FSDBDIR}" -type f -name getVar.sh)
if [[ -f $GETVAR ]]; then
	source "$GETVAR" #TODO: make sure, that the configs exist and are in the right locations, first (or inside of getVar)!!!!
	modFSDBCONFIG=$(find $INITDIR -type f -name fsdb.config)
	intro "$0"
else
	ADMINDIR="/tmp/"
	LOG="$ADMINDIR/$(basename $0 .sh).log"
	FSDBVERSION=fsdb
	error "Can't locate getVar.sh in ${FSDBDIR}."
fi

intro "As a linux tool the fsdb employes many other linux tools. 
	Some of them are part of the standard linux installation; others will need to be installed. 
	This step ensures, that all necessary tools are installed on this computer.
	The following linux tools will be installed or updated on your computer:
	${appArr[@]} \n"
#echo ${appArr[@]}
read -e -p "Are you OK with installing these tools? [Y/n]: " -i "Y" ans
if [[ "$ans" == [Yy] ]]; then
	installLinuxTools
else
	warn "You may run into problems running the fsdb, if the necessary tools are not installed or up-to-date. \nSkipping installation and proceeding.\n"
fi

defaultConfig=$(ls -ltr $(find "${FSDBDIR}" -type f -name "fsdb.config.default") |tail -1 |awk '{print $NF}')

# define final installation directory
if [[ -z $1 || ! -d $1 ]]; then
	defaultInstDir=$(realpath $HOME/$FSDBVERSION)
else
	if [[ $(echo "$1" |sed 's@/$@@') =~ ${FSDBVERSION}$ ]]; then 
		defaultInstDir=$(realpath $1)
	else
		defaultInstDir=$(realpath $1/$FSDBVERSION)
	fi
fi

# interactive part
printf "\t- Step 2: Please define the location to which the fsdb shall be installed.
\tPlease make sure that the path to this location DOES NOT contain whitespaces.
\tAlso please avoid using ~ or $HOME (for the home directory) as this may result in
\tunindended results, depending under which account you run this script.\n"
read -e -p "Path to installation directory: " -i $defaultInstDir -e INSTDIR
if [[ ! $(echo "$INSTDIR" |sed 's@/$@@') =~ ${FSDBVERSION}$ ]]; then
	INSTDIR=$(realpath $INSTDIR/$FSDBVERSION)
fi
# copy fsdb.config.default to locally active location and open for editing --> generate local fsdb.config
printf "\t- Step 3: Please configure this instance according to your local needs.
For more informations on this step please refer to the README at gitlab.\n\n"
read -e -p "The fsdb will be installed to ${INSTDIR}. Is this correct? [Y/n]: " -i "Y" ans
if [[ "$ans" != [Yy] ]]; then
	fail "Abort. Please run this script again.\n"
else
	printf "Moving the downloaded files from the temporary to the final location.\n\n"
	# define 'SCRIPTSDIR' and create it if it doesn't exist, yet.
	defineScriptsDir $INSTDIR/$repoName/scripts 1

	FSDBCONFIG=$SCRIPTSDIR/fsdb.config
	if [[ ! -f $FSDBCONFIG ]]; then
		if [[ ! -f $modFSDBCONFIG ]]; then
			msg "$defaultConfig --> $FSDBCONFIG\n"
			cp -f $defaultConfig $FSDBCONFIG
		else
			msg "$modFSDBCONFIG --> $FSDBCONFIG\n"
			cp -f $modFSDBCONFIG $FSDBCONFIG
		fi
	else
		msg "$FSDBCONFIG already exists.\n"
	fi
	echo "$INITDIR/ ---> $INSTDIR/"
	rsync -Sau --exclude="fsdb.config" $INITDIR/ $INSTDIR/
fi

# remove init-dir
rm -rf $INITDIR

# set unix permissions 
me=$(whoami)
chown -R ${me}:${me} $INSTDIR

skipPerm "Initialization completed. Starting installation."

# start the actual installation and setup process
echo "$INSTDIR/$repoName/install/installFsdb.sh $SCRIPTSDIR"
ls -la "$INSTDIR/$repoName/install/installFsdb.sh"

echo "this scripts exits here during begugging. " 
exit
bash $INSTDIR/$repoName/install/installFsdb.sh $SCRIPTSDIR
