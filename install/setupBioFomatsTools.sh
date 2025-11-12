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

# find and source getVar.sh to set all global variables
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 || "$1" =~ "-" ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
else
	if [[ -d $1 ]]; then
		gv=$(find "$1" -type f -name getVar.sh)
	else
		gv=$(find $(dirname "$1") -type f -name getVar.sh)
	fi
fi

if [[ -f "$gv" ]]; then
	source "$gv"
else
	echo "ERROR: Can't find getVar.sh"
	exit 555
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