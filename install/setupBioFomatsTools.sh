#!/bin/bash
<< README
This script installs the latest version of the bftools


README

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

# find getVar.sh
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
else 
	gv=$(find "$1" -type f -name getVar.sh)
fi

fi [[ -f "$gv" ]]; then
	source "$gv"
else
	SCRIPTSDIR=$(thisDir)
	error "Can't find getVar.sh."
fi
intro "Installing into $SCRIPTSDIR"

TMP=$(mktemp -d)
cd $TMP
wget http://downloads.openmicroscopy.org/bio-formats/latest/artifacts/bftools.zip
if [[ "$(file -bi bftools.zip)" =~ "text" ]]; then
	mv bftool.zip vn
	version=$(grep bio-formats/ vn |sed 's@.*bio-formats/@@' |cut -d "/" -f 1 |sort -u |tail -1)
	wget http://downloads.openmicroscopy.org/bio-formats/${vn}/artifacts/bftools.zip
fi
unzip -d $SCRIPTSDIR -o bftools.zip
chmod -R a+rx $SCRIPTSDIR/bftools/*
cd -
rm -rf $TMP