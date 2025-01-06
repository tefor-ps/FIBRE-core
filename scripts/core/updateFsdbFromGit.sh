#!/bin/bash
<<README
This script is updating the fsdb by pulling the scripts from the online repository
and updating the macros in their active locations 

no parameter needed

README

thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

FSDBDIR=$SCRIPTSDIR/..
cd $FSDBDIR

# get latest version from online repository
git stash
git reset --hard HEAD
git pull

# update macros in their active location
bash $UPDATEMACROS
