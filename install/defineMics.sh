#!/bin/bash
<<README
This script is part of the installation routine of the TPS fsdb23.

This script interactively collects and saves the data needed to set up a connection 
between the computer the fsdb is installed on and the computers which are providing 
the image data to be managed by the fsdb (in most cases microscopes or other 
image-generating devices). 

README


<<STATUS
tested on
- windows: does not apply 
- wsl: 230914; OK
- linux:
STATUS

# set all global variables
thisDir=$(dirname $(realpath $0))
if [[ -z $1 ]]; then
	source $thisDir/../scripts/core/getVar.sh
else 
	source $1/core/getVar.sh
fi

function getIP() {
	while [[ -z $IPaddress ]] ||  [[ ! $IPaddress =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do 
		intro "Enter IP address of remote computer (microscope):"
		read -p "IP adddress: " IPaddress
	done 
	msg "Testing accessibility of $IPaddress. This will take a couple of seconds.\n"
	curl -s --max-time 3 $IPaddress >/dev/null
	res=$?
	ping -c 3 $IPaddress >/dev/null
	res=$[$?*$res]
	if [[ $res -gt 0 ]];then
	 	skipPerm "$IPaddress can currently not be accessed. 'n' will skip further accessibility checks." getIP
	else
		intro "OK, $IPaddress responded."
	fi
}

function getShare(){
	intro "Enter name of shared drive on remote computer (microscope):"
	read -p "name of share: " nameOfShare
}

function getMountPoint(){
	intro "Enter absolute path of mount-point on this computer"
	read -e -p "mount-point: " mountPoint
#check if mountpoint exists, dont' allow overwrite
	if [[ -d $mountPoint ]]; then
		skipRest "$mountPoint already exists. Preparing to re-define this mount-point." getMountPoint
	fi
	mkdir -p $mountPoint
	if [[ $(echo $?) -gt 0 ]];then
	 	skipRest "$mountPoint can currently not be created. Please define an alternative mount-point." getMountPoint
 	fi
}

function getCredName(){ 
	intro "Enter name for credentials file"
	read -e -p "name of credentials file: " -i "$nameOfShare" credName
#check if cred-file exists, dont' allow overwrite
	if [[ -f $AUTHDIR/.cred-$credName ]]; then
		skipRest "A file with this name already exists. ($AUTHDIR/.cred-$credName)"  getCredName
	fi
}

function getCreds(){
	intro "Generating credential file for autonomous access of this comupter to the remote computer (microscope)." 
	intro "Enter the name of the account, which shall be used to connect to the remote computer."
	read -p "account: " admin
	intro "Enter corresponding password (will not display while typing)" 
	read -s -p "password: " pwd
	printf "username=${admin}\npass=${pwd}" >$AUTHDIR/.cred-$credName
	if [[ $(echo $?) -gt 0 ]];then
		error "Something went wrong while writing $AUTHDIR/.cred-$credName . Please control the permission settings."
#TODO: display and/or permission settings automatically.
	else
		intro "Credentials written to $AUTHDIR/.cred-$credName"
		chmod 700 $AUTHDIR/.cred-$credName
	fi
	pwd=$admin
}

function addRemote(){
	intro "Your input was"
	printf $'\r\e[2K\e[36;1m'"\n$header\n$IPaddress $nameOfShare $mountPoint $credName\n"$'\e[0m\n' |column -t
	skipPerm "Control the values above." 
	if [[ ! -f $MICS ]]; then
		printf "#!/bin/bash\n\n" > $MICS
	fi
	printf "\nmountMic $IPaddress $nameOfShare $mountPoint $credName\n" |sudo tee -a $MICS
	dbg "new settings written to $MICS"
}

function defineMic(){
	getIP
	getShare
	getMountPoint
	getCredName
	addRemote
	getCreds
	skipPerm "Preparing to add another microscope." defineMic
}

header="IP name-of-share mount-point credential-name"
if [[ -f $MICS && $(grep -c "mountMic" $MICS) -gt 0 ]]; then
	intro "The following computers can be accessed from this computer ($(hostname))."
	mounts=$(grep "mountMic" $MICS |cut -d " " -f 2- )
	printf $'\r\e[2K\e[36;1m'"\n${header}\n${mounts}\n"$'\e[0m\n' |column -t
	skipPerm "Above list of computers can already be accessed from this computer ($(hostname))." defineMic
else
	warn "User interaction needed: define computers (of microscopes) which shall be accessed by this computer."
	defineMic
fi



