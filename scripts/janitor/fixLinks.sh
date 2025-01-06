#!/bin/bash

<<README
This script controls, if the files (raw data only) in $LABDATADIR and $STORAGEDIR 
are links, not copies, by comparing their inodeIDs, relative paths and file size.

This script expects two parameters:
[$1] = SEARCHSTRING; if entered this string is limiting the execution of this 
script to files with $SEARCHSTRING in their filename. 

README
#fsdb-rev-date: 230331


<<SIDENOTE
mounting via bat-file: https://stackoverflow.com/a/48583228/5269099
SIDENOTE

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

intro $0

debug=3
date |tee -a $LOG

# set default values 
HN=$(hostname)
if [[ -z $1 ]]; then
	SEARCHSTRING="."
else
	SEARCHSTRING=$1
fi

# define arrays to switch input and output 
dirArr=("$STORAGEDIR/$IMPORTS" "$LABDATADIR/$IMPORTS") # TODO: get rid of IMPORTS here. too restrictive.
bnArr=("$D.$HN.dt.st" "$D.$HN.dt.ld")
indArr=("$INDEXDIR/${bnArr[0]}.index" "$INDEXDIR/${bnArr[1]}.index")
inoArr=($(echo ${indArr[@]} |sed 's@\.index@.inodes@g'))

# remove residual indices
for i in ${indArr[@]}; do
	rm -f $i
done

# loop through the filename extensions defined in core.config
for stacktype in $(echo $STACKEXTENSION); do
# loop through the directories defined in array dirArr above
	for i in $(seq 0 $((${#dirArr[@]}-1))); do
		index=${indArr[i]}
# write index
		DIR=${dirArr[i]}
		if [[ "$SEARCHSTRING" == "." ]]; then
			dbg2 "making index for $stacktype on $DIR"
			#echo "find  $DIR -type f -name \"*.$stacktype\" > $index 2>>$LOG"
			find  $DIR -type f -name "*.$stacktype" >>  $index 2>>$LOG
		else
			dbg2 "making index for $stacktype and $SEARCHSTRING on $DIR"
			#echo "find  $DIR -type f -name \"*$SEARCHSTRING*.$stacktype\"  > $index 2>>$LOG "
			find  $DIR -type f -name "*$SEARCHSTRING*.$stacktype"  >> $index 2>>$LOG
		fi
		bash $CHECKPATH $index

		#wc -l $index
# generate inode list
		inodes=${inoArr[i]}
		msg "making inode list for $index"
		while read i; do 
			ls -li "$i"; 
		done < $index > $inodes
		#wc -l $index
	done
done


# compare lists of inodes --> should be identical (both) when linked
	bash $COMPLISTS ${inoArr[0]} ${inoArr[1]}
# conserve result at INDEXDIR
	cp /tmp/$D-${bnArr[0]}* $INDEXDIR
# the files in 'both' are OK, no further action needed.
# for the lists of non-agreement (only1, only2) get the relative path (without LABDATADIR or STORAGEDIR)
msg "making relative paths for data of $stacktype only on $STORAGEDIR"
for i in $(cat $INDEXDIR/$D-${bnArr[0]}-${bnArr[1]}-only1.txt); do 
	grep $i ${inoArr[0]} ; 
done  |awk '{print $NF}' |sed "s@$STORAGEDIR@@g" > $INDEXDIR/${bnArr[0]}-only.short
msg "making relative paths for data only on $LABDATADIR"
for i in $(cat $INDEXDIR/$D-${bnArr[0]}-${bnArr[1]}-only2.txt); do 
	grep $i ${inoArr[1]} ; 
done  |awk '{print $NF}' |sed "s@$LABDATADIR@@g" > $INDEXDIR/${bnArr[1]}-only.short

# if files were copied instead of linked, then these relative paths and file 
# sizes should be identical, however the inodes are different
# compare relative paths
bash $COMPLISTS $INDEXDIR/${bnArr[0]}-only.short $INDEXDIR/${bnArr[1]}-only.short
# conserve result to WORKDIR
cp /tmp/$D-${bnArr[0]}-only* $INDEXDIR

# the results in 'both' are problematic, because they are copies of each other.
# the following is comparing the file sizes
# if they are (approx. (see offset)) the same size, the bigger instance is linked into
# the other location. If the discrepancies are too big, throw an error, which needs 
# to be fixed manually.
echo >> $LOG
date >> $LOG
wc -l $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-both.txt >> $LOG
df $DATAROOT >> $LOG
# get inodes and sizes of results from inode lists.
# $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-both.txt is based on the 'short'/realtiv paths;
# ie. it contains paths without the roots ($STORAGEDIR resp. $LABDATADIR)
for i in $(cat $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-both.txt); do
	msg "$i"
# get inode and file size of files under investigation	
	if [[ $(grep $i$ ${inoArr[1]}|grep -v lock|wc -l) -eq 1 ]]; then
		LD=$(grep $i$ ${inoArr[1]}|grep -v lock )
		LDin=$(echo $LD |cut -d " " -f 1) # inode of file in $LABDATA
		LDfs=$(echo $LD |cut -d " " -f 6) # file size of file in $LABDATA
		dbg2 "$LDin $LDfs"
	else
		printf "out ld : ${i}\n" >> $LOG
		echo $LD >>$LOG
		continue
	fi

	if [[ $(grep $i$ ${inoArr[0]}|grep -v lock|wc -l) -eq 1 ]]; then
		ST=$(grep $i$ ${inoArr[0]}|grep -v lock )
		STin=$(echo $ST |cut -d " " -f 1) # inode of file in $STORAGEDIR
		STfs=$(echo $ST |cut -d " " -f 6) # file size of file in $STORAGEDIR
		dbg2 "$STin $STfs"
	else
		echo "out st : $i" >> $LOG
		echo $ST >> $LOG
		continue
	fi
# compare file sizes
# if identical, replace the copy in $LABDATADIr with a link to its instance in $STORAGEDIR
	if [[ $LDfs -eq $STfs ]]; then 
		if [[ $LDin -ne $STin ]]; then
			msg "copy detected; making new link from $STORAGEDIR/$i to $LABDATADIR/$i"
			ln -vf $STORAGEDIR/$i $LABDATADIR/$i
		fi
	else
# if one instance is within the offset different from the other, replace the smaller by a link to the bigger.
		offset=50
		if [[ $LDfs -gt $STfs ]]; then
			if [[ $LDfs -lt $[$STfs+$offset] ]]; then
				dn=$(dirname $i)
				mkdir -p $STORAGEDIR/$dn
				ln -vf $LABDATADIR/$i $STORAGEDIR/$i
			else
				error  "file sizes are too different $i :\nstorage: ${ST}\t${STsf}\nlabdata: ${LD}\t${LDfs}\n" >> $LOG
				cmp $STORAGEDIR/$i $LABDATADIR/$i >> $LOG
			fi
		else
			if [[ $LDfs -gt $[$STfs-$offset] ]]; then
				dn=$(dirname $i)
				mkdir -p $LABDATADIR/$dn
				ln -vf $STORAGEDIR/$i $LABDATADIR/$i
			else
				error  "file sizes are too different $i :\nstorage: ${ST}\t${STsf}\nlabdata: ${LD}\t${LDfs}\n" >> $LOG
				cmp $STORAGEDIR/$i $LABDATADIR/$i >> $LOG
			fi
		fi
	fi
done

# The elements of 'only1' and 'only2' are missing on the other side. 
# They need ot be linked  to there.
wc -l $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-only1.txt >> $LOG
for i in $(cat $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-only1.txt); do
	dn=$(dirname $i)
	mkdir -p $LABDATADIR/$dn
	ln -f $STORAGEDIR/$i $LABDATADIR/$i >> $LOG
done

wc -l $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-only2.txt >> $LOG
for i in $(cat $INDEXDIR/$D-${bnArr[0]}-only-${bnArr[1]}-only-only2.txt); do
	dn=$(dirname $i)
	mkdir -p $STORAGEDIR/$dn
	ln -f $LABDATADIR/$i $STORAGEDIR/$i >> $LOG 
done

dbg "DONE" 

date >> $LOG
df $DATAROOT >> $LOG

dbg "make sure all permissions are set correctly"
bash $FIXPERMISSIONS

dbg3 "$(date)"


