#!/bin/bash
<<README
This script is writing this README by extracting:
- the introduction from the pre-existing README.md
- the .scripts.config.default from the fsdb installation directory and
- the documentation-section from the shell-scripts in the same directory   
and compiles them into a documentation in markdown format.
README

#fsdb-rev-date: 250911, needs testing

#TODO: This script does not work (yet),as intended. Needs a general overhaul.

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

#define documentation input directory
callDir=$(find $(pwd) -type d -name "documentation")
dbg "Called from $callDir"
modDir=$(realpath $callDir/..)
mod=$(basename $modDir)
dbg "... for module $mod"

dbg2 "thisDir: $thisDir"
dbg2 "callDir: $callDir"

# make backup of pre-existing README.md
#mv $WORKDIR/README.md $WORKDIR/README.bup
README=$(find $(realpath $callDir/..) -name "README.md")
if [[ -z $README ]]; then
	README=$(realpath $callDir/../README.md)
	#touch $README
else
	READMEBUP=$(echo $README |sed 's@.md$@.bup@')
	cp $README $READMEBUP
fi
dbg $README
READMETMP=$(echo $README |sed 's@.md$@.tmp@')
READMEDIR=$(dirname $README)

# integrate introduction from pre-existing README.md
if [[ -f $README ]]; then
	grep -B 1000 -e "------" $README > $READMETMP 
else
	cat $callDir/foreword.md > $READMETMP
fi

# add chapter on installation
cat $callDir/installation.md >> $READMETMP

# integrate 'chapter' .scripts.config
printf "\n## .scripts.config\n\`\`\`bash\n" >> $READMETMP
cat $TEMPLATESDIR/fsdb.config.default |sed 's@\$@\\$@g' >> $READMETMP
# add all other sub-configs
for i in $(find $FSDBDIR -name "*config" |grep -v ./.scripts.config |grep -v ./fsdb.config); do 
	echo
	echo "# ==> Modify values below in $i <=="; 
	cat $i; 
done >> $READMETMP
printf "\n\`\`\`\n------\n" >> $READMETMP

# integrate 'chapter' scripts and macros of the fsdb
printf "## file-specific documentation for the fsdb    \n" >> $READMETMP
printf "(in alphabetical order)\n---\n" >> $READMETMP 
for CATDIR in $(find $FSDBDIR -mindepth 1 -maxdepth 3 -type d -name "fsdb-*" |grep -v bftools|sort -f); do
	CAT=$(basename $CATDIR)
	dbg $CAT
	for script in $(find $CATDIR/ -name "*.sh"  |grep -v test |grep -v xvfb| sort -f); do
		scriptBn=$(basename $script .sh)
		printf "### $CAT :: $scriptBn"
		grep -B 1000 ^README $script |sed -e 's@#!/bin/bash@@' -e 's@^<<README@@' -e 's@^README@@' -e "s@'@\\\'@g"
		echo  "---"
	done  >> $READMETMP
done


# if run for an external moduel, add 'chapters' for its scripts and macros 
if [[ "$callDir" != "$thisDir" ]]; then
	printf "## file-specific documentation for the $mod    \n" >> $READMETMP
	printf "(in alphabetical order)\n---\n" >> $READMETMP 
	modScripts=$modDir/scripts
	dbg2 $modScripts 
	for CATDIR in $(find $modScripts -maxdepth 1 -type d |grep -v ${modScripts}$ |grep -v bftools|sort -f); do
		dbg $CATDIR
		CAT=$(basename $CATDIR)
		dbg $CAT
		for script in $(find $CATDIR/ -name "*.sh"  |grep -v test |grep -v xvfb| sort -f); do
			scriptBn=$(basename $script .sh)
			printf "### $CAT :: $scriptBn"
			grep -B 1000 ^README $script |sed -e 's@#!/bin/bash@@' -e 's@^<<README@@' -e 's@^README@@' -e "s@'@\\\'@g"
			echo  "---"
		done  >> $READMETMP
	done
else
	echo "bla"
fi	

# overwrite old README with the new one.
mv $READMETMP $README

