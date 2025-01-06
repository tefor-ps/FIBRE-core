#!/bin/bash
<<README
completely independent script for the colorization of outputs.
this script should be sourced by the script, which needs to colorize its output.

This script provides the following output (color) modes:
error:		error <-- white on red background, new-line
message:	msg <-- green, no new-line
warning:	warn <-- red, new-line
debug level 1-3: dbg, dbg1, dbg2	<-- magenta
introduction:	intro <-- cyan, new-line
permissive interrupt: interPerm <-- green, new-line, by default 'yes'
restrictive interrupt:	interRest <-- red, new-line, by default 'no"

Alternative default colors:
Foreground colors
39	Default foreground color
30	Black
31	Red
32	Green
33	Yellow
34	Blue
35	Magenta
36	Cyan
37	Light gray

Background colors
49	Default background color
40	Black
41	Red
42	Green
43	Yellow
44	Blue
45	Magenta
46	Cyan
47	Light gray

:: from https://misc.flogisoft.com/bash/tip_colors_and_formatting

README
#fsdb-rev-date: 230313

# set debug level (default 1) by variable of parameter 
getLevel() { 
	if [[ -z $debug ]]; then 
		if [[ -z $DEBUGLEVEL ]]; then 
			debug=1; 
		else 
			debug=$DEBUGLEVEL ; 
		fi ; 
	fi ; 
	echo $debug ;
}

if [[ -z $LOG ]]; then
	td=$(realpath $(dirname $BASH_SOURCE))
	LOGDIR=$td/../../logs
	mkdir -p $LOGDIR
	LOG="$LOGDIR/$D.$(basename $0 .sh).log"
fi

#good explanation of color codes at http://www.andrewnoske.com/wiki/Bash_-_adding_color

# error message on red background
error() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&2 ;}
# green message
msg() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[32;1;40m'"$(basename $0): $@"$'\e[0m\r' || echo "$@"; else echo "$@"; fi >&1 ;}
# red warning message
warn() { if [[ -t 2 ]] ; then date >> $LOG; printf $'\r\e[2K\t\e[31;1;40m'"$(basename $0): $@"$'\e[0m\n' |tee -a $LOG; else echo "$@"; fi >&1 ;}
# magenta debuggin message level 1 (most prevalent)
dbg() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 1 ]]; then printf $'\r\e[2K\t\e[35;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# magenta debugging message level 2
dbg2() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 2 ]]; then printf $'\r\e[2K\t\e[33;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# magenta debugging message level 3
dbg3() { if [[ -t 2 ]] ; then if [[ $(getLevel) -ge 3 ]]; then printf $'\r\e[2K\t\e[34;1;40m'"$(basename $0): $@"$'\e[0m\n'; fi else echo "$@"; fi >&1 ;}
# magenta message with permissive interrupt and user interaction (pot. emergency exit). If answer is empty, go on.
interPerm(){ if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[32;1;40m'"$(basename $0): $@"$'\e[0m\n'; questPerm; else echo "$@"; fi >&1 ;}
# white question and answer used by inter()
questPerm(){ printf "\r\e[2K\tDo you want to proceed? [Y/n]"; read ans; if [[ "$ans" =~ [Yy] ]] || [[ -z $ans ]]; then msg "going ahead\n";else error "${ans}: abort by user" >&2 ; exit 1;fi;}
# magenta messge with restrictive interrupt and user interaction (pot. emergency exit). If answer is empty, exit.
interRest(){ if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[31;1;40m'"$(basename $0): $@"$'\e[0m\n'; questRest; else echo "$@"; fi >&1 ;}
# white question and answer used by inter()
questRest(){ printf "\r\e[2K\tDo you want to proceed? [y/N]"; read ans; if [[ "$ans" =~ [Yy] ]]; then msg "going ahead\ns";else error "${ans}: abort by user" >&2 ; exit 1;fi;}
# cyan text on black background to introduce the current script or say something important
intro() { if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[36;1m'"$@"$'\e[0m\n'; else echo "$@"; fi >&2 ;}

# standardized replies for the skipping-procedures
#skip() { if [[ -t 2 ]] ; then msg "${ans}: skipping this step.\n" >&2 ; else echo "$@"; fi >&2 ; skipFlag=1;}
skip() { 
	if [[ -t 2 ]] ; then 
		warn "skipping: ${task} was not performed." >&2 ; 
	else 
		echo "skipping."; 
	fi >&2 ; 
	skipFlag=1;
}
proceed(){ 
	if [[ -t 2 ]] ; then 
		msg "executing: ${task}."; 
		$task
	else 
		$task; 
	fi >&2 ;
	skipFlag=0;
}
wrong() { 
	if [[ -t 2 ]] ; then 
		error "You answered: ${ans}"; 
		warn "This is not a valid answer. Retry."; 
	else 
		echo "$@"; 
	fi >&2 ;
}
# permissive skip: does NOT skip the next step, when 'yes' or empty 
skipPerm(){ 
	if [[ -t 2 ]] ; then
		task=${@:2}
#		echo ${@:2}
		intro "$1"; 
#		echo -e "\tNext step: ${@:2}"
#		warn "Next step: ${@}"
#		printf "\r\e[2K\tDo you want to proceed? [Y/n]"; 
#		msg "Do you want to proceed? [Y/n]"; 
		read -e -p "Do you want to proceed? [Y/n]: " -i "Y" ans; 
		case $ans in
#			[Yy]|[Yy][Ee][Ss]|"")
			[Yy])
				proceed ${@:2}
				;;
#			[Nn]|[Nn][Oo])
			[Nn])
				skip 
				;;
			*)
				wrong
				skipPerm "$@"
				;;
		esac	
 
	else 
		echo "$@"; 
	fi >&1 
}

# restrictive skip: skips the next step by dedault
skipRest(){ 
	if [[ -t 2 ]] ; then 
		task=${@:2}
		intro "$1"; 
#		echo -e "\tNext step: ${@:2}"
#		warn "Do you want to skip this step? [Y/n]"; 
		read -e -p "Do you want to proceed? [y/N]: " -i "N" ans; 
		case $ans in
#			[Yy]|[Yy][Ee][Ss]|"")
			[Yy])
				proceed ${@:2}
				;;
#			[Nn]|[Nn][Oo])
			[Nn])
				skip $task 
				;;
			*) 
				wrong
				skipRest "$@"
				;;
		esac	
 
	else 
		echo "$@"; 
	fi >&1 
}
