#!/bin/bash
<<README
Initialization script for the installation of the file system based database (fsdb).

This script is using the information within the configuration file 
(.scripts.config) for the construction of the fsdb.

PREREQUISITES
This script expects the following steps have been done beforehand, manually.
- install operating system (latest Ubuntu (server) LTS) with lvm enabled
- create RAID [*]
- set up lvm for the data partition [*]
- install nagios for system supervision [*]
- the computers of the acquisition machines need to be prepared for remote access 
of the storage server (this computer).

steps marked [*] are optional but strongly recommended in this context.

PARAMETERS
This script (optionlally) accepts the installation directory as first and only parameter ($1).

README

error() { 
	if [[ -t 2 ]] ; then 
		printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' 
	else 
		echo "$@"; 
		fi >&2 
}

sudoer() {
## ROOT PRIVILEGES
# because for the for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
if [ $(whoami) != "root" ]; then 
	error "WARNING: This script needs to be run with root-privileges."
	exit
fi
}

makeScriptsDir() {
# move fsdb from temporary to user-defined location (SCRIPTSDIR)
	mkdir -p $SCRIPTSDIR
	rsync -Sau $INITDIR/$fsdbVersion/ $WORKDIR/
}

function installLinuxTools(){
# tools installation 
## composite command using aptitude
	printf "Updating Linux repos. This may take a moment or two.\n"
	apt -qq update
	apt install -y nload htop tree vlc samba vim nano gitg meld xvfb libimage-exiftool-perl ffmpeg curl unzip p7zip-full gparted cifs-utils nfs-common rename imagemagick 
	sudo apt autoremove --purge
}

# empty terminal
clear

# confirm root status
sudoer

# define version of fsdb
fsdbVersion=fsdb23

# define initial installation directory 
INITDIR=/tmp

# define final installation directory
if [[ -z $1 || ! -d $1 ]]; then
	defaultInstDir=$(realpath ~/)
else
	defaultInstDir=$(realpath $1)
fi

#remove leftovers from earlier installations
rm -rf /$INITDIR/$fsdbVersion

printf "As a linux tool the fsdb many other linux tools; some of them are not part of the standard linux installation. 
This step ensures, that all necessary tools are installed on this computer.
The following linux tools will be installed or updated on your computer:\n"
for i in nload htop tree vlc samba vim nano gitg meld xvfb libimage-exiftool-perl ffmpeg curl unzip p7zip-full gparted cifs-utils nfs-common rename imagemagick; do 
	echo $i
done
read -e -p "Are you OK with installing these tools? [Y/n]: " -i "Y" ans
if [[ "$ans" == [Yy] ]]; then
	installLinuxTools
else
	printf "You may run into problems running the fsdb, if the necessary tools are not installed or up-to-date. Proceeding.\n"
fi

# download of fsdb-scripts from gitlab
repo=https://gitlab.com/arnimjenett/$fsdbVersion
printf "\nWelcome to the installer of the file system based database (fsdb).
\t- Step 1: Cloning the latest version of the fsdb from $repo to temporary directory $INITDIR/$fsdbVersion \n" 
cd $INITDIR/
#git clone --depth 1 -b installer $repo
git clone --depth 1 -b main $repo
if [[ $? -gt 0 ]]; then 
	error "Can't clone fsdb from $repo"; 
	exit 1; 
fi

# interactive part
printf "\t- Step 2: Please define the location to which the fsdb shall be installed.
\tPlease make sure that the path to this location DOES NOT contain whitespaces.\n"
read -e -p "Path to installation directory: " -i $defaultInstDir INSTDIR
INSTDIR=$(realpath $INSTDIR)
# copy fsdb.config.default to locally active location and open for editing --> generate local fsdb.config
printf "\t- Step 3: Please configure this instance according to your local needs.
For more informations on this step please refer to the README at gitlab.\n\n"
read -e -p "The fsdb will be installed to ${INSTDIR}. Is this correct? [Y/n]: " -i "Y" ans
if [[ "$ans" != [Yy] ]]; then
	printf "Abort. Please run this script again.\n"
	exit
else
	printf "Moving the downloaded files from the temporary to the final location.\n\n"
	SCRIPTSDIR=$INSTDIR/$fsdbVersion/scripts
	mkdir -p $SCRIPTSDIR
	FSDBCONFIG=$SCRIPTSDIR/fsdb.config
	if [[ ! -f $FSDBCONFIG ]]; then
		cp -u $INITDIR/$fsdbVersion/install/templates/fsdb.config.default $FSDBCONFIG
	fi
	rsync -Sau $INITDIR/$fsdbVersion/ $INSTDIR/$fsdbVersion/
fi

# set all global variables
source $INSTDIR/$fsdbVersion/scripts/core/getVar.sh
## from here on this script uses the variables defined in the configuration file (.scripts.config)

# set unix permissions 
me=$(whoami)
chown -R ${me}:${me} $INSTDIR/$fsdbVersion/

skipPerm "Initialization completed. Starting installation."

# start the actual installation and setup process
bash $INSTDIR/$fsdbVersion/install/installFsdb.sh $SCRIPTSDIR 
