#!/bin/bash
<<README
This script installs the correct (OS-specific) version of Fiji into the fsdb.
If it encounters the "Windows subsystem for Linux (WSL)" it installed the Linux version.

README

if [[ "$(whoami)" != "root" ]]; then
	echo "This script needs to be run with sudo. Exiting."
	exit
fi

# define the location of your Fiji installation
if [[ -z $1 ]]; then
	if [[ $(pwd |grep -c fsdb-minimal) -eq 0 ]]; then
		DEVDIR="$(pwd)/dev-dir"
	else
		DEVDIR="$(pwd |sed 's@/fsdb-minimal.*@@')"
	fi
else
	DEVDIR="$(realpath "$1")"
fi

FIJIDIR="$DEVDIR/fsdb-minimal/scripts/Fiji.app/"
if [[ -f $(find . -name "ImageJ-*") ]]; then
	echo "Fiji already exists. Exiting."
	exit
fi
# create temporary directory for download and unpacking.
TMPDIR=$DEVDIR/tmp
mkdir -pv $TMPDIR
cd $TMPDIR

printf "\n ... installing FIJI for "
# download OS-specific Fiji-version
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	# Linux
	if [[ $(uname -r |grep -c [mM]icrosoft) -gt 0 ]]; then
		echo "WSL"
	else
		echo "Linux"
	fi
	wget https://downloads.imagej.net/fiji/latest/fiji-linux64.zip
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	echo "MacOSX"
	wget https://downloads.imagej.net/fiji/latest/fiji-macosx.zip
elif [[ "$OSTYPE" == "cygwin" ]]; then
	# POSIX compatibility layer and Linux environment emulation for Windows
	echo "cygwin"
	wget https://downloads.imagej.net/fiji/latest/fiji-win64.zip
elif [[ "$OSTYPE" == "msys" ]]; then
	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
	echo "Windows; e.g., Git Bash, msysGit, Mingw32"
	wget https://downloads.imagej.net/fiji/latest/fiji-win64.zip
elif [[ "$OSTYPE" == "freebsd"* ]]; then
	# FreeBSD
	echo "FreeBSD"
	wget https://downloads.imagej.net/fiji/latest/fiji-linux64.zip
else
	# Unknown.
	printf "\r\t\tUnknown OS. Exiting."
	uname -a
	exit
fi

# unpack Fiji, move it to the correct location, and remove the temporary directory
mkdir -pv $FIJIDIR
unzip fiji*zip -d $FIJIDIR/..
rm -rf $TMPDIR

# update fiji
cd $FIJIDIR
FIJI=$(find . -maxdepth 1 -type f |grep mage)
sudo $FIJI --update update
