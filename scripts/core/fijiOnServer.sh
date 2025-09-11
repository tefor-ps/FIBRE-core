#!/bin/bash
<<README
This script is a wrapper to run fiji headlessly.
It was build to run scripts of the fsdb secDataGeneration directly on a headless storage or compute server. 
It expects two parameters as input:
$1 = absolute path to the macro to be run
$2 = absolute path to the image to work with

For macros, which have a build-in image-opening-mechanism the order can 
also be reversed ($1:macro; $2:image), which provides the image as a 
parameter to the macro (e.g. caller.ijm).

For running on the storage-server (headless) this script is using the 
helper-wrapper xvfb-run-safe.sh, which makes sure, that there is no 
screen-clash when this is run in multiple instances at the same moment.
xvfb-run-safe.sh searches for a non-used screen before starting fiji.
xvfb-run-safe.sh must be located in the same folder as this script.

Other computers run fiji interactively as $ADMIN .

README
#fsdb-rev-date: 250911

## ======
## FUNCTION DEFINITIONS
## ======

function installLatestJava(){
	latestJDK="$( apt-cache search openjdk |grep -e "-jdk" |grep "(JDK)" |grep -v headless |sort |head -1 |cut -d " " -f 1)"
	apt-get install -y "$latestJDK"
}

function complain(){
# output not-treated files to log and dedicated file
	dbg "$maxsize"
	dbg "$fileSize"
	dbg "$minsize"
	if [[ "$fileSize" -gt "$maxsize" ]]; then
		error "$rawImage is too big" |tee -a "$LOG"
		echo "$rawImage" |tee -a "$LOGDIR/$D.tooBig.txt"
	elif [[ "$fileSize" -lt "$minsize" ]]; then
		error "$rawImage is too small" |tee -a "$LOG"
		echo "$rawImage" |tee -a "$LOGDIR/$D.tooSmall.txt"
	fi
}

fijiOnX11(){
# TODO: needs testing and potentially setup/modification of XAuth	
	dbg "X11"
	cd "$FIJIDIR" || exit
	FIJI="$FIJIDIR/ImageJ-linux64"


	timeout ${TIMEOUTMINUTES}m "$FIJI" "-macro $MACRO $IMG" 2>>"$LOG"
	#timeout ${TIMEOUTMINUTES}m "./ImageJ-linux64 -macro $MACRO $IMG" 2>>"$LOG"
}

fijiOnLinux(){
	dbg "Linux - xvbf"
	FIJI="$FIJIDIR/ImageJ-linux64"

#check if helper script exists
	ls -l "$COREDIR/xvfb-run-safe.sh"
	if [[ $? -gt 0 ]]; then
		echo "fatal error: $COREDIR/xvfb-run-safe.sh appears to be missing. exiting."
		exit
	fi
	
	echo "timeout time: ${TIMEOUTMINUTES}m" >>$LOG

# run secdataGeneration in virtual environment (not headlessly) for as long as $TIMEOUTMINUTES minutes.
# after $TIMEOUTMINUTES minutes, kill process because we have to assume, that it is stuck.
	timeout ${TIMEOUTMINUTES}m "$COREDIR/xvfb-run-safe.sh" "$FIJI -macro $MACRO $IMG" 2>>"$LOG"
}

fijiOnWindows() {
	dbg "Windows"
	#for e.g., MobaXterm; doesn't really start-up
	# TODO: make this work
	cd "$FIJIDIR" ||exit
	FIJI="$FIJIDIR/ImageJ-win64.exe"
	
	"$FIJI" -macro "$MACRO" "$IMG" 2>>"$LOG"
}

function fail(){
	#intro "$@"
	date
	printf "\033[31mError in $(basename $0)::${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}


## ======
## FUNCTION CALLS
## ======


# define FSDBDIR, which is the root of the fsdb, 
# dynamically on the basis of the location of this script
thisDir="$(realpath "$(dirname "$0")")"
if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
	FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
else
	FSDBDIR="$(realpath $thisDir/../../..)"
fi

# set all global variables
GETVAR=$(find $FSDBDIR -type f -name getVar.sh)
if [[ -f $GETVAT ]]; then
	source "$GETVAR"
else
	fail "Can't locate getVar.sh."
fi
	
intro "$0"

debug=1

# if no java is installed on the current machine, install the defaulr java runtime envorinment
which java
if [[ $? -eq 1 ]]; then
	installLatestJava
else
	jv=$(java --version |head -1 |cut -d " " -f 2 |cut -d "." -f 1)
	if [[ $jv -le 8 ]]; then
		installLatestJava
	fi
fi

dbg2 "$0 $@"
# ensure, that all needed network drives are mounted
#sudo mount -a #DEPRECATED?
#bash $MOUNTMICS #TODO: check if this is really needed, here. #DEPRECATED

# make sure FIJIDIR and the scripts within are executable
sudo chmod -R 770 "$FIJIDIR"

# define fiji to work with 
if [ $(uname) == "Linux" ]; then
	FIJI="$FIJIDIR/ImageJ-linux64"
else
	FIJI="$FIJIDIR/ImageJ-win64.exe"
fi
echo "fiji: $FIJI" |tee -a "$LOG"

# populate variables
if [[ "$(echo "$1" |awk -F "." '{print $NF}')" == "ijm" ]]; then
	if [[ -f "$1" ]]; then 
		MACRO="$(realpath "$1")"
	else
		echo "first parameter empty. exiting."
		exit
	fi
	if [[ -f "$2" ]]; then
		IMG="$(realpath "$2")"
	else
		echo "second parameter empty."
	fi

elif [[ "$(echo "$2" |awk -F "." '{print $NF}')" == "ijm" ]]; then
	if [[ -f "$2" ]]; then
		MACRO="$(realpath "$2")"
	else
		echo "second parameter empty."
	fi
	if [[ -f "$1" ]]; then 
		IMG="$(realpath "$1")"
	else
		echo "first parameter empty. exiting."
		exit
	fi

else
	echo "Can't find the macro in $1 and $2. Exiting."
	exit
fi
echo "macro: $MACRO" |tee -a "$LOG"
echo "image: $IMG" |tee -a "$LOG"

whoami >> "$LOG"

#check file size and make the decision to run on the current hardware or to skip the processing of this image 
if [[ -f "$IMG" ]]; then
	fileSize=$(ls -l "$IMG" |cut -d " " -f 5)
else
	fileSize="$minsize"
fi 

echo "filesize: $fileSize" |tee -a "$LOG"

if [[ "$fileSize" -gt "$maxsize"  ||  "$fileSize" -lt "$minsize" ]]; then
	complain
	exit
fi

# define fiji to work with 
if [[ "$(uname)" == "Linux" ]]; then
	if [[ $(grep -ic microsoft /proc/version) -gt 0 ]]; then
		echo "WSL" |tee -a "$LOG"
		fijiOnX11
	else
		echo "Linux" |tee -a "$LOG"
		if [[ $( echo $DISPLAY |wc -c ) -gt 1 ]]; then
			fijiOnX11
		else
			fijiOnLinux
		fi
	fi
else
	echo "Windows" |tee -a "$LOG"
	fijiOnWindows
fi

# clean-up leftovers of this run
sudo rm -vf /tmp/ImageJ-*stub

if [[ $? -eq 124 ]]; then
	echo "$0 TIMEOUT" >>"$LOG"
else
	echo "$0 DONE" >>"$LOG"
fi
date >>"$LOG"

exit 0
