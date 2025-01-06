#/bin/bash

# set all global variables
thisDir=$(dirname $(realpath $0))
source $thisDir/../core/getVar.sh

debug=0

intro $0

if [[ $1 -eq 1 ]]; then
        FORCEINDEX=1
else
        FORCEINDEX=0
fi

# define local variables
INDEX=$INDEXDIR/$D.labdata.index
inputDir=$LABDATADIR/$IMPORTS
PROJECTS=$INDEXDIR/$D.projects.index

for i in p.index l.index p.content l.content pnw.content lnw.content; do
	rm -f /tmp/$i
done

if [[ ! -d $inputDir ]]; then 
	mkdir -p $inputDir
fi
if [[ ! -f $INDEX || $FORCEINDEX ]]; then
	find $inputDir -type f > $INDEX
fi
if [[ ! -f $PROJECTS || $FORCEINDEX ]]; then
	find $PROJECTSDIR -type d > $PROJECTS
fi

for suff in fsdb secData; do
	echo $suff
#for i in $(find /DATA/tps/labdata/projects/ -type d -name "*-$suff" ); do 
	for i in $(grep -e -$suff$ $PROJECTS); do
		clear -x
#		echo
		msg "$i\n"
#		dbg "$i"
		find $i -type f > /tmp/p.index
		cat /tmp/p.index |sed "s@.*$suff@@" |sort -u >/tmp/p.content
		dn=$(basename $i);
		dbg "$dn"
		for l in $(grep $dn $INDEX |sed "s@${suff}.*@$suff@" |sort -u); do
			find $l -type f
		done > /tmp/l.index
		cat /tmp/l.index |sed "s@.*$suff@@" |sort -u >/tmp/l.content
	#	wc -l /tmp/*.index
	#	wc -l /tmp/*.content
		sudo bash $COREDIR/compareListsWithWhitespaces.sh /tmp/l.content /tmp/p.content 
		while read line; do 
			nw=$(echo "$line" |sed 's@ @_@g'); 
			printf "${nw} $line\n"; 
		done </tmp/${D}-l-p-only1.txt >/tmp/lnw.content
	       	while read line; do
       			nw=$(echo "$line" |sed 's@ @_@g');
			printf "${nw} $line\n";
	        done </tmp/${D}-l-p-only2.txt >/tmp/pnw.content
		sudo bash $COMPLISTS /tmp/lnw.content /tmp/pnw.content 


		for i in $(cat /tmp/${D}-lnw-pnw-only1.txt); do
        		dbg "l --> p";
			dbg2 " i: $i";
			ss=$(grep $i /tmp/lnw.content |cut -d " " -f 2);
			dbg2 "ss: $ss"
			t=$(grep $ss /tmp/l.index);
			dbg2 " t: $t";
		        dn=$(dirname $t|awk -F"/" '{print $NF}')
		        dbg2 "dn: $dn";
			ld=$($(dirname $(grep -e "$dn" /tmp/p.index) 2>/dev/null) |sed "s@$dn.*@$dn@"|sort -u |grep -e "$dn");
	#		if [[ -z $ld ]]; then
	#			dbg2 "constructing projects dir"
	#			
	#
	#			pd=/
	#		fi
		        dbg2 "ld: $ld" ;
			dbg "link ${t} to ${ld}"
			if [[ $debug -gt 0 ]]; then
				ln -v $t $ld
			else
				msg "link ${t} to ${ld}"
				ln $t $ld
			fi
			done
	
		for i in $(cat /tmp/${D}-lnw-pnw-only2.txt); do
		        dbg "p --> l";
		        dbg2 " i: $i";
			bn=$(basename $i)
			dbg2 "bn: $bn"
		        ss=$(grep $i /tmp/pnw.content |cut -d " " -f 2);
		        dbg2 "ss: $ss"
		        t=$(grep $ss /tmp/p.index);
		        dbg2 " t: $t";
		        dn=$(dirname $t|awk -F"/" '{print $NF}')
		        dbg2 "dn: $dn";
			ld=$($(dirname $(grep -e "$dn" /tmp/l.index) 2>/dev/null) |sed "s@$dn.*@$dn@" |sort -u |grep -e "$dn")
			if [[ -z $ld ]];then
				dbg2 "constructing labdata output dir"
				SID=$(echo $bn |cut -d "_" -f 1)
				PID=$(echo $SID |sed -e 's@[0-9a-z]*@@g')
				fd=/
				if [[ $(echo $dn |grep -c fsdb$) -eq 0 ]];then
					for frag in $(echo $t |tr "/" "\n"); do 
						if [[ $(echo $frag |grep -c fsdb$) -gt 0 ]]; then 
							fd=$frag; 
						fi
					done
				fi
				case $PID in
					A | AJ)
						pid=Arnim
						;;
					C)
						pid=Payel
						;;	
					DC)
						pid=Dorian
						;;
					F | FL)
						pid=Fabrice
						;;	
					M | MS)
						pid=Matthieu
						;;
					P | PA)
						pid=Pierre
						;;
					*)
						ld=NA
						;;
				esac
			fi
			ld=$inputDir/$pid/$fd/$dn
			if [[ "$ld" != "NA" ]]; then 
			        dbg2 "ld: $ld"
				mkdir -p $ld
	                        dbg "link ${t} to ${ld}"
	                         if [[ $debug -gt 0 ]]; then

        	                         ln -v $t $ld
                	         else
                        	         msg "link ${t} to ${ld}"
					 ln $t $ld
	                         fi   
			else
				echo $t >>$LOGDIR/$D.p2lSync.error
			fi
		done
		rm /tmp/*.content
#		read ans
	done
done
