#!/bin/bash
<<README
This script is updating the fsdb by pulling the scripts from the online repository
and updating the macros in their active locations 

no parameter needed

README
# fsdb revision 251023

#DEPRECATED?

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# find and source getVar.sh to set all global variables
source getVar
intro $(basename $0)

#debug=2

cd $FSDBDIR

# get latest version from online repository
git stash
git reset --hard HEAD
git pull

# update macros in their active location
bash $UPDATEMACROS
