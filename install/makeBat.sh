#!/bin/bash
<<README
This script creates an windows script (.bat) and provides the necessary tooling 
(Bat_To_Exe_Converter.exe) to convert it to an executable file.
The executable is mean to be run on windows computers, which need to connect to 
the fsdb-server. 

After double-click it will ask the user for access credentials (his/her unix 
account name and password on the server) and connect the server to the local 
machine using the following drive letters:
A: for the archive
X: for the internal exchange dircetory
Y: for the external exchange dircetory
Z: for the data directory

README

#fsdb-rev-date: 250911, needs testing


# set all global variables
thisDir="$(realpath "$(dirname "$0")")"
# define FSDBDIR, which is the root of the fsdb, 
# dynamically on the basis of the location of this script
if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
	FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
else
	FSDBDIR="$(realpath $thisDir/../..)"
fi

# set all global variables or at least the ones necessary
GETVAR=$(find $FSDBDIR -type f -name getVar.sh)
if [[ -f $GETVAR ]]; then
	source "$GETVAR"
	intro "$0"
else
	ADMINDIR="/tmp/"
	LOG="$ADMINDIR/$(basename $0 .sh).log"
	FSDBVERSION=fsdb
	error "Can't locate getVar.sh."
fi


thisIP=$(hostname -I |tr " " "\n" |grep -v 192.168 |grep -v 127.0.0.1 |head -1)
lab=$(echo $LAB |tr '[:lower:]' '[:upper:]')
bat=$ADMINDIR/mount${lab}.bat
dbg $lab
dbg $thisIP

printf "@echo off 2>nul

echo Welcome to the $LAB network
echo This will connect the $LAB server to your computer.
echo If nothing more happens, please make sure, that you 
echo are connected to your network by cable.

net use x: /Delete
net use x: \\\\\\\\${thisIP}\\\\${LAB}-exchange
net use y: /Delete
net use y: \\\\\\\\${thisIP}\\\\${CONSORTIUM}-export
net use z: /Delete
net use z: \\\\\\\\${thisIP}\\\\${LAB}-data
net use a: /Delete
net use a: \\\\\\\\${thisIP}\\\\${LAB}-archive
explorer /root, " > $bat

exe=$(basename $bat .bat).exe
warn "User interaction needed: convert $bat to exe"
intro "At $MATDIR you find Bat_To_Exe_Converter.exe."
intro "Run that application on a Windows computer and convert $bat to an executable ($exe), which can be run by a simple double-click."
intro "Distribute the resulting $exe on the Desktops of your windows workstations."
intro "Double-click on the $exe will connect the workstation with the storage server."

for item in $TEMPLATESDIR/Bat_To_Exe_Converter.exe $bat $TEMPLATESDIR/fsdb-connect-logo.ico; do
	for outDir in ~ /tmp/ $EXCHANGEDIR; do 
		cp $item $outDir
	done
done

intro "For convenient access"
for i in Bat_To_Exe_Converter.exe ${bat} fsdb-connect-logo; do
	intro "\t$i"
done	
intro "were copied to"
for i in /tmp $(realpath ~) ${EXCHANGEDIR}; do
	intro "\t$i"
done
intro "on this computer."
