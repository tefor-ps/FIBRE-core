#!/bin/bash
<<README
compareLists.sh; formerly known as tcf_runLISTagainstLIST.sh
This script compares two lists of identical elements using 'sort' and 'diff'.
INPUT:
$1 = first list.
$2 = second list.
[$3] = debug level. can be empty. by default chatty (1).

OUTPUT:
three files in /tmp/.
names are constructed from
- the current date (format yymmdd)
- the basename of the first list
- the basename of the second list
- the string "only1", "only2" or "both"
- file extension: .txt

underlying concept:
- from two lists find and store in separeate lists the elements, which are only 
in one (or the other) of the lists or in both of them.

mode of function:
- isolate first column of input lists --> C1 
- sort C1 --> C1.sorted
- run a diff on the two C1.sorted
- separate the diff-output into three different files (on the basis of diff's annotation (<, >)

note: 
- the input data are treated as space-delimited tables.
- only the first column of the input data will be taken into account by this script.

README
# today's timestamp
D=$(date +%y%m%d)

## helper functions
if [ -z $3 ]; then
	debug=1	#by default chatty
else
	debug=$3
fi

## define directory where shell scripts can be found
scriptDir=$(dirname $(realpath $0))
scriptName=$(basename $0 .sh)
# today's timestamp
D=$(date +%y%m%d)
# define log file
logDir=$scriptDir/logs/
mkdir -p $logDir
LOG=$logDir/$D.$scriptName.$instanceNum.log

if [ -f $scriptDir/fun_colMsg.sh ]; then
	source $scriptDir/fun_colMsg.sh
else
	# error message on red background
	error() { if [[ -t 2 ]] ; then printf $'\e[37;1;41m'"ERROR:\t$@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}
	# green message
	msg() { if [[ -t 2 ]] ; then printf $'\t\e[32;1;40m'"$scriptName: $@"$'\e[0m\r'; else echo "$@"; fi >&1 ;}
	# red warning message
	warn() { if [[ -t 2 ]] ; then printf $'\t\e[31;1;40m'"$scriptName: $@"$'\e[0m\n'; else echo "$@"; fi >&1 ;}
	# blue debugging message level 1 (most prevalent)
	dbg() { if [[ -t 2 ]] ; then if [ $debug -gt 0 ]; then printf $'\t\e[34;1;40m'"$scriptName: $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
	# dark blue debugging message level 2
	dbg2() { if [[ -t 2 ]] ; then if [ $debug -gt 1 ]; then printf $'\t\e[34;3;40m'"$scriptName: $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
	# magenta message with interrupt and user interaction (pot. emergency exit)
	inter(){ if [[ -t 2 ]] ; then printf $'\t\e[35;1;40m'"$scriptName: $@"$'\e[0m\n'; quest; else echo "$@"; fi >&1 ;}
	# white question and answer used by inter()
	quest(){ printf "Is this correct? [y/n]"; read -u 2 ans; if [[ "$ans" != [Yy] ]]; then error "${ans}: abort by user" >&2 ; exit 1;else msg "going ahead";fi;}
fi

dbg "$(date)"
msg "$0\n"

remove() {
	if [ -e $1 ]; then
		dbg2 "$1"
		rm -f $1
	fi
}

#==============================================================================
# "keepTemp" toggles if the temporary files are kept or deleted after finishing.
keepTemp=0
# timestamp for identification of the temporary files
TS=$(date +%N)
suff=$(echo $1 |awk -F "." '{print $NF}')
bn1=$(basename $1 .$suff)
suff=$(echo $2 |awk -F "." '{print $NF}')
bn2=$(basename $2 .$suff)
#define variables for temporary files.
a="/tmp/$TS.a.txt"
a1="/tmp/$TS.a1.txt"
b="/tmp/$TS.b.txt"
b1="/tmp/$TS.b1.txt"
d1="/tmp/$TS.diff1.txt"
d2="/tmp/$TS.diff2.txt"
p1="/tmp/$TS.pool1.txt"
p2="/tmp/$TS.pool2.txt"
t1="/tmp/$TS.temp1.txt"
t2="/tmp/$TS.temp2.txt"
#define variables for results.
only1="/tmp/$D-$bn1-$bn2-only1.txt"
only2="/tmp/$D-$bn1-$bn2-only2.txt"
both="/tmp/$D-$bn1-$bn2-both.txt"
# if the temporary files already exist, delete them and create them anew.
for i in $only1 $only2 $both $a $a1 $b $b1 $d1 $d2 $p1 $p2 $t1 $t2; do
	remove $i
done
# detecting differences:
# make the input files local.
msg "detecting differences: sorting $1 \r"
awk '{print $1}' "$1" |sort -u >$a &
#aClean=$(awk '{print $1}' "$1" |sort -u)
msg "detecting differences: sorting $2 \r"
awk '{print $1}' "$2" |sort -u >$b &
wait
#inter "check for \nwc -l $a \nand\nwc -l $b" #(for debug only)
# pool input data
msg "detecting commonalities: pooling input"
cat $a >$t2
cat $b >>$t2
cat $t2 |sort -u >$p2 &
#bClean=$(awk '{print $1}' "$2" |sort -u)
# generate diff on input files
msg "detecting differences: computing difference \r"
diff -aE --strip-trailing-cr --speed-large-files $a $b >$d1
# separate diff in two result files
msg "detecting differences: writing $only1"
grep "<" $d1 |awk '{print $2}'>$only1 &
msg "writing $only2"
grep ">" $d1 |awk '{print $2}'>$only2 &
wait
# detecting commonalities:
# pool differences
msg "detecting commonalities: pooling differences"
cat $only1 >$t1
cat $only2 >>$t1
cat $t1 |sort >$p1
# generate diff from pools
msg "detecting commonalities: computing difference \r"
diff -aE --strip-trailing-cr --speed-large-files $p1 $p2 >$d2
# port everything which is in the import files but not in the "differences pool" into result file.
msg "detecting commonalities: writing $both"
grep ">" $d2 |awk '{print $2}' >$both

# clear temporary files if toggled on.
if [ $keepTemp -eq 0 ]; then
	remove $a1 $b1 $d1 $d2 $p1 $p2 $t1 $t2
fi

# display results
if [ $debug -eq 3 ]; then
	msg "=========================\nin first list only\n"
	cat $only1
	msg "=========================\nin second list only\n"
	cat $only2
	msg "=========================\nin both list\n"
	cat $both
fi
if [ $debug -gt 3 ]; then
        msg "=========================\nin first list only\n"
        for one in $(cat $only1); do grep ^$one $1; done
        msg "=========================\nin second list only\n"
        for two in $(cat $only2); do grep ^$two $2; done
        msg "=========================\nin both list\n"
        for three in $(cat $both); do grep ^$three $1; done
        for three in $(cat $both); do grep ^$three $2; done
fi
a=$(wc -l $only1|sed -e 's@^ *@@g'|tr " " "\t")
b=$(wc -l $only2|sed -e 's@^ *@@g'|tr " " "\t")
c=$(wc -l $both|sed -e 's@^ *@@g'|tr " " "\t")
msg "\n=========================
list1:\t$(wc -l ${1}|sed -e 's@^ *@@g'|tr " " "\t")
list2:\t$(wc -l ${2}|sed -e 's@^ *@@g'|tr " " "\t")
all results can be found in /tmp/ :
a:\t$a\t${1}
b:\t$b\t${2}
c:\t$c\n"

# to avoid littering remove all temp-files
rm -f /tmp/$TS.*

dbg "$(date)"
