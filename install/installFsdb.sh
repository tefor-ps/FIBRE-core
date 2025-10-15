#!/bin/bash
<<README
Installation script of the file system based database (fsdb)

Run after the initialization, this script takes care of
- software installations
- user accounts
- file system structure
- set up the scheduling
- samba installation, setup and exposure 
- connection to data/image acquisition machines

PARAMETERS
$1 is the path to path to the fsdb-core scripts-directory. 
By default this script can also be run to reconfigure an fsdb-installation.   
$2 can take the string 'config' [optional], which trigggers the opening of the 
pre-existing .scripts.config in an editor for implementing changes.

RESOURCES
Tools marked [*] are coming with the fsdb, because they can not be installed through aptitude. 
The others are installed together using aptitude.
- image treatment, fiji [*]: http://fiji.sc/#download
- X virtual framebuffer, xvfb: https://en.wikipedia.org/wiki/Xvfb
xvfb-run-safe [*]: motivated by https://stackoverflow.com/a/30336424 
- video generation, ffmpeg: https://www.ffmpeg.org/
- Bio-Formats libraries, bftools: https://docs.openmicroscopy.org/bio-formats/latest/users/comlinetools/index.html
- tool to read exif-tags, exiftool : https://www.sno.phy.queensu.ca/~phil/exiftool/
- video player, vlc : https://www.videolan.org/vlc/index.html
- version control, gitg: https://wiki.gnome.org/Apps/Gitg/
- diff-tool, meld: http://meldmerge.org/
- text editor, jedit: http://www.jedit.org/   
   vim: https://en.wikipedia.org/wiki/Vim_(text_editor)
- communication across OS-borders: samba: https://en.wikipedia.org/wiki/Server_Message_Block

README

#TODO: integrate into extractReadme
#TODO: modify function-descriptions to be reflected in extractREADME (--> <<README)
#TODO: reknit this to use a dynamic list of setup-scritps instead of internal functions.

## ======
## FUNCTION DEFINITIONS
## ======


function installLatestJava(){
	latestJDK=$( apt-cache search openjdk |grep -e "-jdk" |grep "(JDK)" |grep -v headless |sort |head -1 |cut -d " " -f 1)
	apt-get install -y $latestJDK
}

# decprecated because out-sourced
#	function installFiji() {
#		# installation of fiji and the fsdb macros within
#		dbg " Next step: fiji installation."
#		cd /tmp
#		wget https://downloads.imagej.net/fiji/latest/fiji-linux64.zip
#		unzip -d $SCRIPTSDIR -o fiji-linux64.zip && rm fiji-linux64.zip 
#		#rsync -Sauv /tmp/Fiji.app/ $SCRIPTSDIR/Fiji.app/
#		chmod -R a+rx $SCRIPTSDIR/Fiji.app/
#		sudo ln -s $SCRIPTSDIR/Fiji.app/ImageJ-linux64 /usr/local/bin/fiji #TODO: check if this is really necessary!!
#		# update fiji
#		fiji --update update
#	}

function installBFtools(){
	# install bftools
	dbg "Next step: installation of bioformats tools (bftools)."
	cd /tmp
	wget http://downloads.openmicroscopy.org/bio-formats/latest/artifacts/bftools.zip
	unzip -d $SCRIPTSDIR -o bftools.zip && rm bftools.zip
	chmod -R a+rx $SCRIPTSDIR/bftools/*
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

error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}


## ======
## FUNCTION CALLS
## ======

#debug=2

if [[ -d $1 ]]; then
	defineScriptsDir $1
else
	defineScriptsDir
fi

# update all scripts and macros of the fsdb
printf "updating fsdb...\n"
cd $SCRIPTSDIR
git pull 
printf "fsdb-scripts updated.\n"

# activate (default) configuration files as needed #TODO: check if deprecated
for i in $(find $SCRIPTSDIR -name "*config.default"); do 
	conf=$(echo $i |sed 's@.default@@'); 
	if [[ -f $conf  ]]; then 
#		dbg2 "$conf already exists"
		printf "$conf already exists\n" 
	else
		cp -v $i $conf
	fi
done

# set all global variables
GETVAR=$(find $SCRIPTSDIR -name getVar.sh)
if [[ $2 == "config" ]];then
	source $GETVAR config
else
	source $GETVAR
fi

## from here on this script uses the variables defined in the configuration file (.scripts.config)

# install java
<<javainstall
 In its latest version bftools depends on java8 or later to function. Otherwise it will throw an error: 
 java.lang.UnsupportedClassVersionError: loci/formats/tools/ImageInfo : Unsupported major.minor version 52.0 
 This can be fixed by installing the latetes java as described here. Today (2019) this is java11.
javainstall
which java
if [[ $? -eq 0 ]]; then
	jv=$(java --version |head -1 |cut -d " " -f 2 |cut -d "." -f 1)
	if [[ $jv -gt 8 ]]; then
		msg "The installed java version (${jv}) is sufficient.\n"
	else
		java --version
		warn "If you don't see a java version bigger than 8 displayed above, you will need to install java."
		#skipPerm "Next step: java installation." installLatestJava
		skipPerm "Next step: java installation." bash bash $MATDIR/setupFiji.sh
	fi
else
	warn "There is no java installed on your system." 
	skipPerm "Next step: java installation." installLatestJava
fi

<<fijiinstall
fiji is just imagej - batteries included. This is an application used extensively within the fsdb. 
fijiinstall
if [[ -f $FIJISDIR/fiji ]]; then
	skipRest "Fiji is already installed. Do you want to reinstall anyhow?" installFiji
else
	installFiji
fi

<<bftoolsinstall
The OME bio-format tools are a central component of the fsdb. They are responsible for seamless reading and writing 
of image file formats. more info on these tools at https://www.openmicroscopy.org/bio-formats/
bftoolsinstall
if [[ -f $SCRIPTSDIR/bftools/showinf ]]; then
	skipRest "bftools are already installed. Do you want to reinstall anyhow?" installBFtools
else
	installBFtools
fi
	
# set up samba 
<<smb_install
the script smb-install installs the service samba and creates a smb.config file 
which enables (highly restrictive) data sharing with the users of the fsdb (as 
defined in fsdb.config). 
It DOES NOT deal with samba-accounts/passwords as this task is handled by makeAccounts 
smb_install
which samba
if [[ $? -eq 0 ]]; then
	skipRest "Samba $(samba --version) is installed on this system. Do you want to reinstall anyhow?" bash $MATDIR/smb-install.sh $SCRIPTSDIR   
else
	skipPerm "Next step: samba-installation." bash $MATDIR/setupSmb.sh $SCRIPTSDIR
fi

# generate user accounts
<<makeAccounts
the script makeAccounts creates the necessary unix user account and assigns them 
to the necessary groups and permissions (as defined in fsdb.config).
makeAccounts
skipPerm "Next step: generation of user accounts." sudo bash $MATDIR/makeAccounts.sh $SCRIPTSDIR

dbg "accounts set up. Next step: generation of folder structure."


# generate fsdb folder structure
<<folders
only create user's directories in $IMPORT. 
even this step is not really needed, because fetchDataFromMicroscopes.sh will dynamically create these folders.
folders
intro "building data storage structure."
for account in $USER; do
	for location in $STORAGEDIR $LABDATADIR; do
			DIR=$location/$IMPORTS/$account
			mkdir -pv $DIR
			chown $account:$GROUP $DIR >> $LOG 2>&1
			chmod 770 $DIR >> $LOG 2>&1
	done
done	

#all other directories are generated by a function in getVar.sh
makeDirs

# set permissions of folder structure
<<fix_permissions
This script is setting the unix permissions to enable proper function of the fsdb.
fix_permissions
skipPerm "Next step: set permissions for folders." bash $FIXPERMISSIONS
dbg "folders set up. "



# set up cron
<<setCron
The processes of the fsdb are triggered in regular intervals using cron. 
The script setCron is configuring the local cron-job.
setCron
skipPerm "Next step: setup of scheduling for the fsdb-scripts." bash $MATDIR/setCron.sh $SCRIPTSDIR


# define new remote computers (acquisition machines) for data import
<<defineMics

defineMics
skipPerm "Next  step: defining new acquisition machines." bash $MATDIR/defineMics.sh $SCRIPTSDIR


# mount the image acqisition machines.
<<mount_mics

mount_mics
skipPerm "mounting the acquisition machines. " bash $MOUNTMICS $SCRIPTSDIR

dbg "acquisition machines connected"

# build mounting.exe for connecting windows machines to server.
<<makeBat
This script is writing a .bat file and provides the tooling (Bat_To_Exe_Converter.exe) to convert it to an executable. 
The executable is meant to be run on windows computers to connect them easily to the fsdb-server. 
makeBat
skipPerm "Next (last) step: Build of connection-tool for windows desktop computers." bash $MATDIR/makeBat.sh $SCRIPTSDIR

intro "Congrats. Your fsdb is ready to use"

skipPerm "If you modified the smb.conf, it is highly recommended to reboot this computer now" reboot
