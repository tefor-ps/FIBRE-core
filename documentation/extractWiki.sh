#!/bin/bash
<<README
This script is writing this README by extracting:
- the introduction from the pre-existing README.md
- the .scripts.config.default from the fsdb installation directory and
- the documentation-section from the shell-scripts in the same directory   
and compiles them into a documentation in markdown format.
README

#TODO: test this again

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


wikidir=$thisDir/../../../fsbd23.wiki #TODO: make this more stable

mkdir -p $wikidir

dbg $wikidir

# write home.md from foreword
if [[ -f $WORKDIR/README.md ]]; then
	grep -B 1000 -e "------" $WORKDIR/README.md > $wikidir/home.md
else
	cp $thisDir/foreword.md $wikidir/home.md
fi

# add chapter on installation
cp $thisDir/installation.md  $wikidir/Installation-of-the-fsdb.md

# add chapter / table on the config
cp $thisDir/conf.md $wikidir

# integrate 'chapter' .scripts.config
printf "\n## .scripts.config\n\`\`\`bash\n" >> $WORKDIR/README.md
cat $TEMPLATESDIR/fsdb.config.default |sed 's@\$@\\$@g' >> $WORKDIR/README.md
# add all other sub-configs
for i in $(find $FSDBDIR -name "*config" |grep -v ./.scripts.config |grep -v ./fsdb.config); do 
	echo
	echo "# ==> Modify values below in $i <=="; 
	cat $i; 
done >> $WORKDIR/README.md
printf "\n\`\`\`\n---\n" >> $WORKDIR/README.md


# integrate 'chapter' scripts and macros 
printf "## file-specific documentation for the fsdb    \n" >> $WORKDIR/README.md
printf "(in alphabetical order)\n---\n" >> $WORKDIR/README.md 
for CATDIR in $(find $FSDBDIR -mindepth 1 -maxdepth 3 -type d -name "fsdb-*" |grep -v bftools|sort -f); do
	CAT=$(basename $CATDIR)
	for script in $(find $CATDIR/ -name "*.sh"  |grep -v test |grep -v xvfb| sort -f); do
		scriptBn=$(basename $script .sh)
		printf "### $CAT :: $scriptBn"
		grep -B 1000 ^README $script |sed -e 's@#!/bin/bash@@' -e 's@^<<README@@' -e 's@^README@@' -e "s@'@\\\'@g"
		echo  "----"
	done  >> $WORKDIR/README.md
done



