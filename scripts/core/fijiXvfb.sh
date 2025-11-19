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
#fsdb-rev-date: 251118

forceXvfb=1 # if this is greater than zero, it forces the execution in xvfb (on real Linux only) 
force=1

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
	#FIJI="$FIJIDIR/fiji"
	#timeout ${TIMEOUTMINUTES}m "$FIJI" "-macro $MACRO $PARAM $IMG" 2>>"$LOG"
	#timeout ${TIMEOUTMINUTES}m "$FIJI" "$IMG -macro $MACRO $PARAM" 2>>"$LOG"
	echo "timeout ${TIMEOUTMINUTES}m fiji $IMG -macro $MACRO $PARAM 2>>\"$LOG\""
	timeout ${TIMEOUTMINUTES}m fiji $IMG -macro $MACRO $PARAM 2>>"$LOG"
}

fijiOnLinux(){
	dbg "Linux - xvbf"
	#FIJI="$FIJIDIR/fiji"
#check if helper script exists
	#ls -l "$COREDIR/xvfb-run-safe.sh"
	#if [[ $? -gt 0 ]]; then		
	if [[ ! -f "$CORESCRIPTS/xvfb-run-safe.sh" ]]; then
		error " Can't find $CORESCRIPTS/xvfb-run-safe.sh"
	fi
	echo "timeout time: ${TIMEOUTMINUTES}m" >>$LOG
# run macro in virtual environment (not headlessly) for as long as $TIMEOUTMINUTES minutes.
# after $TIMEOUTMINUTES minutes, kill process because we have to assume, that it is stuck.
	#timeout ${TIMEOUTMINUTES}m "$COREDIR/xvfb-run-safe.sh" "$FIJI -macro $MACRO $PARAM $IMG" 2>>"$LOG"
	#timeout ${TIMEOUTMINUTES}m "$COREDIR/xvfb-run-safe.sh" "$FIJI $IMG -macro $MACRO $PARAM" 2>>"$LOG"
	timeout ${TIMEOUTMINUTES}m "$CORESCRIPTS/xvfb-run-safe.sh" "fiji $IMG -macro $MACRO $PARAM" 2>>"$LOG"
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

#	# define fiji to work with 
#	if [ $(uname) == "Linux" ]; then
#		#FIJI="$FIJIDIR/ImageJ-linux64"
#		FIJI="$FIJIDIR/fiji"
#	else
#		FIJI="$FIJIDIR/ImageJ-win64.exe"
#	fi
#	echo "fiji: $FIJI" |tee -a "$LOG"

# populate variables
inArr=(${@})
iArr=()
mArr=()
pArr=()
j=0

maxInd=$((${#inArr[@]}-1))
dbg "maxInd: $maxInd"

for i in $(seq 0 $((${#inArr[@]}-1))); do		# analyze all provided parameters
	dbg "$i ${inArr[$i]}"				# for debugging
	if [[ -f "${inArr[$i]}" ]]; then	# work on parameters, which are files
		if [[ "${inArr[$i]}" =~ ".ijm" ]]; then # work on files, which are macros
			mArr[$j]="${inArr[$i]}"		# assign to macro-array (mArr)
			dbg2 "$j: ${mArr[$j]}"
			unset 'inArr[$i]'			# remove from input array (inArr)
			dbg2 ":: $((${#inArr[@]}-1))"
			if [[ $i -le $maxInd ]]; then
				ni=$((i+1))					# increase index (next index, ni) to search for the parameters of the current macro
				dbg2 "ni: $ni"
				#read ans
				if [[ -f ${inArr[$ni]}  ]]; then # if the next parameter is a file, there are no parameters to the current macro 
					echo "next file"
				else
					tArr=()					# initialise temporary array (tArr) empty
					while [[ ! -f ${inArr[$ni]} && $ni -le $maxInd ]]; do # assign all non-file parameters to tArr
						tArr+=("${inArr[$ni]}")
						dbg2 "$ni: ${tArr[@]}" 
						unset 'inArr[$ni]'	# ... and remove them from inArr
						ni=$((ni+1))
					done
					pArr[$j]="${tArr[@]}"	# assign macro parameters to parameter array (pArr) at the current index (j)
				fi
			fi
			j=$((j+1))
		else
			iArr+=("${inArr[$i]}")		# if a detected file is not a macro, it must be an image; assign ti image array (iArr)
			unset 'inArr[$i]'			# ... and remove from inArr.
		fi
	fi
done

dbg3 "IN: ${inArr[@]}"
dbg3 "I: ${iArr[@]}"
dbg3 "M: ${mArr[@]}"
dbg3 "P: ${pArr[@]}"

if [[ ${#inArr[@]} -eq 0 ]]; then	# If all elements of the list of inputs were recognized,...
	for IMG in ${iArr[@]}; do		# ... process each provided image ...
		for i in ${!mArr[@]}; do	# ... with each provided macro (respecing their parameters)
			echo
			#echo $i
			MACRO=${mArr[$i]}
			PARAM=$(echo ${pArr[$i]} |sed 's@ @,@g')
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
			
			if [[ "$fileSize" -gt "$maxsize"  ]]; then
				complain	# exit, if file size is too big
			fi
			if [[ $force -eq 0 ]]; then
				if [[  "$fileSize" -lt "$minsize" ]]; then
					complain	# exit, if file size is too small
				fi
			fi
			# define fiji to work with 
			if [[ "$(uname)" == "Linux" ]]; then
				if [[ $(grep -ic microsoft /proc/version) -gt 0 ]]; then
					echo "WSL" |tee -a "$LOG"
					fijiOnX11
				else
					echo "Linux" |tee -a "$LOG"
					if [[ $( echo $DISPLAY |wc -c ) -gt 1 && $forceXvfb -eq 0 ]]; then
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
