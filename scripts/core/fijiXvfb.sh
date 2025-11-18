#!/bin/bash
<<README
This script is a wrapper to run fiji headlessly.
It accepts multiple images and macros, which must be directly followed by their 
macro-specific parameters (multiple parameters accepted).

For running on (storage-)servers (headless) this script is using the 
helper-wrapper xvfb-run-safe.sh, which prevents screen-clashs when running 
multiple instances in parallel.
xvfb-run-safe.sh searches for a non-used screen before starting fiji.
xvfb-run-safe.sh must be located in the same folder as this script.

Other computers run fiji interactively as $ADMIN .

README
#fsdb-rev-date: 251112

forceXvfb=1 # if this is greater than zero, it forces the execution in xvfb (on real Linux only) 

source getVar
intro $(basename $0)

#debug=2

## ======
## FUNCTION DEFINITIONS
## ======

function installLatestJava(){
	latestJDK="$( apt-cache search openjdk |grep -e "-jdk" |grep "(JDK)" |grep -v headless |sort |head -1 |cut -d " " -f 1)"
	apt-get install -y "$latestJDK"
}

function complain(){
# output not-treated, files to log and dedicated file
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
	exit
}

fijiOnX11(){
# TODO: needs testing and potentially setup/modification of XAuth	
	dbg "X11"
	cd "$FIJIDIR" || exit
	FIJI="$FIJIDIR/fiji"
	#timeout ${TIMEOUTMINUTES}m "$FIJI" "-macro $MACRO $PARAM $IMG" 2>>"$LOG"
	timeout ${TIMEOUTMINUTES}m "$FIJI" "$IMG -macro $MACRO $PARAM" 2>>"$LOG"
}

fijiOnLinux(){
	dbg "Linux - xvbf"
	FIJI="$FIJIDIR/fiji"
#check if helper script exists
	#ls -l "$COREDIR/xvfb-run-safe.sh"
	#if [[ $? -gt 0 ]]; then		
	if [[ ! -f "$COREDIR/xvfb-run-safe.sh" ]]; then
		echo "fatal error: $COREDIR/xvfb-run-safe.sh appears to be missing. Exiting."
		exit
	fi
	echo "timeout time: ${TIMEOUTMINUTES}m" >>$LOG
# run macro in virtual environment (not headlessly) for as long as $TIMEOUTMINUTES minutes.
# after $TIMEOUTMINUTES minutes, kill process because we have to assume, that it is stuck.
	#timeout ${TIMEOUTMINUTES}m "$COREDIR/xvfb-run-safe.sh" "$FIJI -macro $MACRO $PARAM $IMG" 2>>"$LOG"
	timeout ${TIMEOUTMINUTES}m "$COREDIR/xvfb-run-safe.sh" "$FIJI $IMG -macro $MACRO $PARAM" 2>>"$LOG"
}

fijiOnWindows() {
	dbg "Windows"
	#for e.g., MobaXterm; doesn't really start-up
	# TODO: make this work
	cd "$FIJIDIR" ||exit
	FIJI="$FIJIDIR/ImageJ-win64.exe"
# run macro on image in normal fiji
	#"$FIJI" -macro "$MACRO" "$PARAM" "$IMG" 2>>"$LOG"
	"$FIJI" "$IMG" -macro "$MACRO" "$PARAM"  2>>"$LOG"
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
# if no java is installed on the current machine, install the latest java runtime envorinment
#DEPRECATED?
which java >/dev/null
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
	#FIJI="$FIJIDIR/ImageJ-linux64"
	FIJI="$FIJIDIR/fiji"
else
	FIJI="$FIJIDIR/ImageJ-win64.exe"
fi
echo "fiji: $FIJI" |tee -a "$LOG"

# populate variables
inArr=(${@})
iArr=()
mArr=()
pArr=()
j=0

for i in $(seq 0 ${#inArr[@]}); do
	if [[ -f "${inArr[$i]}" ]]; then
		if [[ "${inArr[$i]}" =~ ".ijm" ]]; then
			mArr[$j]="${inArr[$i]}"
			#echo "$j: ${mArr[$j]}"
			unset 'inArr[$i]'
			ni=$((i+1))
			if [[ ${inArr[$ni]} =~ ".ijm" ]]; then
				echo "next macro"
			else
				tArr=()
				while [[ ! -f ${inArr[$ni]} ]]; do
					tArr+=("${inArr[$ni]}")
					#echo "$ni: ${tArr[@]}" 
					unset 'inArr[$ni]'
					ni=$((ni+1))
				done
				pArr[$j]="${tArr[@]}"
			fi
			j=$((j+1))
		else
			iArr+=("${inArr[$i]}")
			unset 'inArr[$i]'
		fi
	fi
done

#echo "IN: ${inArr[@]}"
#echo "I: ${iArr[@]}"
#echo "M: ${mArr[@]}"
#echo "P: ${pArr[@]}"

if [[ ${#inArr[@]} -eq 0 ]]; then
	for IMG in ${iArr[@]}; do
		for i in ${!mArr[@]}; do
			echo
			#echo $i
			MACRO=${mArr[$i]}
			PARAM=${pArr[$i]}
			echo "macro: $MACRO" |tee -a "$LOG"
			echo "param: $PARAM" |tee -a "$LOG"
			echo "image: $IMG" |tee -a "$LOG"

			whoami >> "$LOG"
			
			# check file size and make the decision to run on the current hardware or to skip the processing of this image
			if [[ -f "$IMG" ]]; then
				fileSize=$(ls -l "$IMG" |cut -d " " -f 5)
			else
				fileSize="$minsize"
			fi 
			
			echo "filesize: $fileSize" |tee -a "$LOG"
			
			if [[ "$fileSize" -gt "$maxsize"  ||  "$fileSize" -lt "$minsize" ]]; then
				complain
			fi
			
			# define fiji to work with 
			if [[ "$(uname)" == "Linux" ]]; then
				if [[ $(grep -ic microsoft /proc/version) -gt 0 ]]; then
					echo "WSL" |tee -a "$LOG"
					fijiOnX11
				else
					echo "Linux" |tee -a "$LOG"
					if [[ $( echo $DISPLAY |wc -c ) -gt 1 || $forceXvfb -gt 0 ]]; then
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
		done
	done
else
	echo "ERROR: unclear elements in call: ${inArr[@]}. EXITING." |tee -a "$LOG"
	exit
fi

date >>"$LOG"

exit 0
