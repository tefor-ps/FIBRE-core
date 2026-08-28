#!/bin/bash

# Shared output helpers for FSDB shell scripts.
#
# This file is intended to be sourced. Sourcing it is deliberately free of
# filesystem side effects: it does not search for configuration, create a log
# directory, or assign LOG. A caller that wants logging must set LOG itself.
#
# Public message functions and their streams:
#   msg                 stdout
#   dbg, dbg2, dbg3     stdout
#   warn                stderr
#   error, intro        stderr
#
# Colour is used only when the destination stream is a terminal. Debug-level
# filtering is independent of terminal detection, so cron and redirected runs
# behave in the same way as interactive runs.

# fsdb-rev-date: 260828

# Return the effective debug level without changing a global variable.
#
# The legacy `debug` variable takes precedence over DEBUGLEVEL. Invalid values
# fall back to level 1, which preserves the historical default.
getLevel() {
	local level=${debug:-${DEBUGLEVEL:-1}}

	if [[ ! $level =~ ^[0-3]$ ]]; then
		level=1
	fi

	printf '%s\n' "$level"
}

# Append a message to the configured log, if there is one.
#
# Logging must never hide or replace the original terminal message. In
# particular, an absent or unwritable LOG is not itself a fatal error.
_fsdb_log() {
	local text=${1:-}

	[[ -n ${LOG:-} ]] || return 0
	printf '%b\n' "$text" >> "$LOG" 2>/dev/null || true
}

# Print a message without allowing its contents to become a printf format.
#
# Arguments:
#   $1  destination: stdout or stderr
#   $2  ANSI colour sequence without the leading escape character
#   $3  plain message text
#   $4  line ending: newline or carriage-return
_fsdb_emit() {
	local destination=${1:-stdout}
	local colour=${2:-}
	local text=${3:-}
	local ending=${4:-newline}
	local fd=1
	local terminator='\n'

	if [[ $destination == stderr ]]; then
		fd=2
	fi

	if [[ $ending == carriage-return ]]; then
		terminator='\r'
	fi

	if [[ -t $fd && -n $colour ]]; then
		printf '\r\e[2K\e[%sm%b\e[0m%b' \
			"$colour" "$text" "$terminator" >&"$fd"
	else
		printf '%b%b' "$text" "$terminator" >&"$fd"
	fi
}

# White text on a red background. Errors are written to stderr and logged.
error() {
	local text="ERROR:\t$0: $*"

	_fsdb_log "$(date)"
	_fsdb_log "$text"
	_fsdb_emit stderr '37;1;41' "$text"
}

# Green status message. Status messages are discrete log events, not an
# in-place progress indicator, so they always end with a newline. A carriage
# return allowed the next prompt or message to erase important diagnostics such
# as "SDG is paused" on an interactive terminal.
msg() {
	local text="\t$(basename -- "$0"): $*"

	_fsdb_emit stdout '32;1;40' "$text"
}

# Red warning. Warnings now intentionally use stderr, while ordinary messages
# and debug output remain on stdout.
warn() {
	local text="WARN:\t$(basename -- "$0"): $*"

	_fsdb_log "$(date)"
	_fsdb_log "$text"
	_fsdb_emit stderr '31;1;40' "$text"
}

# Emit a debug message if the configured level reaches the requested level.
_fsdb_debug() {
	local required_level=${1:-1}
	local colour=${2:-35;1;40}
	shift 2 || true
	local text="\t$(basename -- "$0"): $*"

	(( $(getLevel) >= required_level )) || return 0
	_fsdb_emit stdout "$colour" "$text"
}

# Debug messages, from the most common (level 1) to most detailed (level 3).
dbg() {
	_fsdb_debug 1 '35;1;40' "$@"
}

dbg2() {
	_fsdb_debug 2 '33;1;40' "$@"
}

dbg3() {
	_fsdb_debug 3 '34;1;40' "$@"
}
# green message with permissive interrupt and user interaction (pot. emergency exit). If answer is empty, go on.
interPerm(){ if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[32;1;40m'"$(basename $0): $@"$'\e[0m\n'; questPerm; else echo "$@"; fi >&1 ;}
# white question and answer used by inter()
questPerm(){ 
#	printf "\r\e[2K\tDo you want to proceed? [Y/n]\n"; 
	intro "Do you want to proceed? [Y/n]"; 
	read -p $'\t' -i "Y" -e ans; 
	if [[ "$ans" =~ [Yy] || -z $ans ]]; then 
		msg "going ahead\n";
	elif [[ "$ans" =~ [Nn] ]]; then
		error "abort by user"; >&2
		exit 1;
	else
		error "invalid answer: ${ans} --> abort by user" >&2; 
		exit 2;
	fi ;
}
# red messge with restrictive interrupt and user interaction (pot. emergency exit). If answer is empty, exit.
interRest(){ if [[ -t 2 ]] ; then printf $'\r\e[2K\t\e[31;1;40m'"$(basename $0): $@"$'\e[0m\n'; questRest; else echo "$@"; fi >&1 ;}
# white question and answer used by inter()
questRest(){
#	printf "\r\e[2K\tDo you want to proceed? [y/N]\n"; 
	intro "Do you want to proceed? [y/N]"; 
	read -p $'\t' -i "N" -e ans; 
	if [[ "$ans" =~ [Yy] ]]; then 
		msg "going ahead\n";
	elif [[ "$ans" =~ [Nn] ]]; then
		error "abort by user.";
		exit 1;
	else 
		error "invalid answer: ${ans} --> abort by user" >&2 ; 
		exit 2;
	fi ;
}
# Cyan text used to introduce a script or highlight important information.
intro() {
	_fsdb_emit stderr '36;1' "\t$*"
}

# Report the calling context and terminate with the established exit status.
# All call-stack access has a default so this also works at the top level under
# `set -u`.
fail() {
	local function_name=${FUNCNAME[1]:-main}
	local caller=${FUNCNAME[2]:-}
	local context=$function_name

	if [[ -n $caller ]]; then
		context="$caller:$function_name"
	fi

	warn "$(date)"
	warn "$context: $*"
	warn "Exiting."
	exit 128
}

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
		intro "$1"; 
		intro "Do you want to proceed? [Y/n/e]: "
		read -p $'\t' -i "Y" -e ans; 
		case $ans in
			[Yy])
				proceed ${@:2}
				;;
			[Nn])
				skip $task
				;;
			[Ee])
				fail "Abort by user."
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
		intro "Do you want to proceed? [y/N/e]: "
		read -p $'\t' -i "N" -e ans; 
		case $ans in
			[Yy])
				proceed ${@:2}
				;;
			[Nn])
				skip $task 
				;;
			[Ee])
				fail "Abort by user."
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
