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
thisDir=$(dirname $(realpath $0))
source $thisDir/../scripts/core/getVar.sh

dbg $WORKDIR/README.md

# make backup of pre-existing README.md
mv $WORKDIR/README.md $WORKDIR/README.bup

# integrate introduction from pre-existing README.md
if [[ -f $WORKDIR/README.md ]]; then
	grep -B 1000 -e "------" $WORKDIR/README.md > $WORKDIR/README.md 
else
	cat $thisDir/foreword.md > $WORKDIR/README.md
fi
# add chapter on installation
cat $thisDir/installation.md >> $WORKDIR/README.md
# integrate 'chapter' .scripts.config
printf "\n## .scripts.config\n\`\`\`bash\n" >> $WORKDIR/README.md
cat $TEMPLATESDIR/fsdb.config.default |sed 's@\$@\\$@g' >> $WORKDIR/README.md
# add all other sub-configs
for i in $(find $SCRIPTSDIR -name "*config" |grep -v ./.scripts.config |grep -v ./fsdb.config); do 
	echo
	echo "# ==> Modify values below in $i <=="; 
	cat $i; 
done >> $WORKDIR/README.md
printf "\n\`\`\`\n---\n" >> $WORKDIR/README.md


# integrate 'chapter' scripts and macros 
printf "## file-specific documentation for the fsdb    \n" >> $WORKDIR/README.md
printf "(in alphabetical order)\n---\n" >> $WORKDIR/README.md 
for CATDIR in $(find $SCRIPTSDIR -maxdepth 1 -type d |grep -v ${SCRIPTSDIR}$ |grep -v bftools|sort -f); do
	CAT=$(basename $CATDIR)
	for script in $(find $CATDIR/ -name "*.sh"  |grep -v test |grep -v xvfb| sort -f); do
		scriptBn=$(basename $script .sh)
		printf "### $CAT :: $scriptBn"
		grep -B 1000 ^README $script |sed -e 's@#!/bin/bash@@' -e 's@^<<README@@' -e 's@^README@@' -e "s@'@\\\'@g"
		echo  "---"
	done  >> $WORKDIR/README.md
done



