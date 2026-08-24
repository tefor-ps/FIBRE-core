#!/bin/bash
<< README
This script installs the latest version of the bftools


README

# cyan text on black background to introduce the current script or say something important
intro() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[36;1m'"$@"$'\e[0m\n'; else echo "$@"; fi >&2 ;}

# error message; white on red background
error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}

function fail(){
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

## ======
## FUNCTION CALLS
## ======

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# get variables of fsdb from getVar.sh
if ! source getVar; then
	dir=$thisDir 
	for _ in $(seq 1 4); do
		GV=$(find "$dir" -name "getVar.sh" -print -quit)
		if [[ -f $GV ]]; then 
			source "${GV}"
			break 
		else
			dir="$(dirname "$dir")"
		fi
	done
	if [[ ! -f "${GV}" ]]; then
		echo "ERROR: Can't find getVar.sh"
		exit 555
	fi
fi
intro $(basename $0)

#debug=2

intro "Installing into $SCRIPTSDIR"

TMP=$(mktemp -d)
cd $TMP
echo $TMP
wget http://downloads.openmicroscopy.org/bio-formats/latest/artifacts/bftools.zip
if [[ "$(file -bi bftools.zip)" =~ "text" ]]; then
	mv bftools.zip vn
	version=$(grep bio-formats/ vn |sed 's@.*bio-formats/@@' |cut -d "/" -f 1 |sort -u |tail -1)
	wget http://downloads.openmicroscopy.org/bio-formats/${version}/artifacts/bftools.zip
fi
unzip -d $SCRIPTSDIR -o bftools.zip
chmod -R a+rx $SCRIPTSDIR/bftools/*
cd -
#rm -rf $TMP