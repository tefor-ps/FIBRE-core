#!/bin/bash
<<README
This script sets up the minimal version of the fsdb.

README

if [[ "$(whoami)" != "root" ]]; then
	echo "This script needs to be run with sudo. Exiting."
	exit
fi

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

# define the location of your development environment/location
if [[ -z $1 ]]; then
	if [[ $(pwd |grep -c fsdb-minimal) -eq 0 ]]; then
		DEVDIR="$(pwd)/dev-dir"
	else
		DEVDIR="$(pwd |sed 's@/fsdb-minimal.*@@')"
	fi
else
	DEVDIR="$(realpath "$1")"
fi

# create development location and move into it 
mkdir -pv "$DEVDIR"
echo "$DEVDIR" 

if [[ $(pwd |grep -c fsdb-minimal) -eq 0 ]]; then
# clone the minimal version of the fsdb into your development location
	cd "$DEVDIR" || exit 
	printf "\n... getting https://gitlab.com/tefor/fsdb-minimal.git\nYou may need to type your credentials for this operation.\n"
	git clone https://gitlab.com/tefor/fsdb-minimal.git
else
	cd "$DEVDIR/fsdb-minimal/" || exit
	printf "\n... pulling https://gitlab.com/tefor/fsdb-minimal.git\nYou may need to type your credentials for this operation.\n"
	git pull
fi
# activate default configs within fsdb-minimal
find "$DEVDIR/fsdb-minimal/" -name "*config.default" |while read -r defaultConfig; do
	config=${defaultConfig//.default/}
	cp -v "$defaultConfig" "$config"
done

# as Fiji is OS-specific it is installed directly from https://imagej.net/
FIJIINSTALLER=$(find "$DEVDIR" -name setupFiji.sh)
echo "$FIJIINSTALLER"
sudo bash "$FIJIINSTALLER" "$DEVDIR"

