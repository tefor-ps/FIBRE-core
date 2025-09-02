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
mkdir -pv "$TMPDIR"
cd "$TMPDIR" || exit

printf "\n ... installing FIJI for "
# download OS-specific Fiji-version
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	# Linux
	if [[ $(uname -r |grep -c "[mM]icrosoft") -gt 0 ]]; then
		echo "WSL"
	else
		echo "Linux"
	fi
	FIJI=fiji-latest-linux64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	echo "MacOSX"
	FIJI=fiji-latest-macos64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "cygwin" ]]; then
	# POSIX compatibility layer and Linux environment emulation for Windows
	echo "cygwin"
	FIJI=fiji-latest-win64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "msys" ]]; then
	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
	echo "Windows; e.g., Git Bash, msysGit, Mingw32"
	FIJI=fiji-latest-win64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "freebsd"* ]]; then
	# FreeBSD
	echo "FreeBSD"
	FIJI=fiji-latest-linux64-jdk.zip
	MD5=${FIJI}.md5
else
	# Unknown.
	printf "\r\t\tUnknown OS. Exiting."
	uname -a
	exit
fi

wget https://downloads.imagej.net/fiji/latest/$FIJI
wget https://downloads.imagej.net/fiji/latest/$MD5

if [[ "$(md5sum $FIJI |awk '{print $1}')" != "$(cat $MD5)" ]]; then
	echo "ERROR: md5 checksum mismatch. Exiting."
	exit 1
fi

# unpack Fiji, move it to the correct location, and remove the temporary directory
mkdir -pv "$FIJIDIR"
unzip fiji*zip
rsync -Sauv Fiji/ "$FIJIDIR"

# update fiji
cd "$FIJIDIR" || exit
FIJI=$(find $(pwd) -maxdepth 1 -type f -name "fiji*")
printf "\n ... updating Fiji\n"
sudo "$FIJI" --update update

# clean up
rm -rfv "$TMPDIR"
