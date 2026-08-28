#!/bin/bash

# Resolve machine-specific FSDB processing limits.
#
# This file defines functions only and is safe to source repeatedly. The
# calling script must provide warn() and dbg(), normally via fun_colMsg.sh.

# fsdb-rev-date: 260828

setMachineProfile() {
	local reported_hostname=${1:-}
	local short_hostname
	local normalized_hostname
	local profile_found=1

	if [[ -z $reported_hostname ]]; then
		reported_hostname=$(hostname -s 2>/dev/null || hostname)
	fi

	# Match the short hostname case-insensitively. This also accepts callers
	# that supply a fully qualified hostname such as Monster.example.org.
	short_hostname=${reported_hostname%%.*}
	normalized_hostname=${short_hostname,,}

	case $normalized_hostname in
		monster)
			COMP=monster
			minsize=100000000
			maxsize=250000000000
			ORDER=size
			;;
		beast)
			COMP=beast
			minsize=100000000
			maxsize=250000000000
			ORDER=size
			;;
		pwe-t630-tefor-2)
			# This host historically uses the shared "beast" identity.
			COMP=beast
			minsize=1000000000
			maxsize=250000000000
			ORDER=size
			;;
		celph-gif)
			COMP=celph-gif
			minsize=1000000
			maxsize=6000000000
			ORDER=size
			;;
		tefor-gif)
			COMP=tefor-gif
			minsize=1000000
			maxsize=20000000000
			ORDER=age
			;;
		celph-lyon)
			COMP=celph-lyon
			minsize=1000000
			maxsize=6000000000
			ORDER=size
			;;
		*)
			COMP=$short_hostname
			minsize=1000000
			maxsize=4000000000
			ORDER=age
			profile_found=0
			;;
	esac

	export COMP minsize maxsize ORDER

	if (( ! profile_found )); then
		warn "No processing profile is configured for host '$reported_hostname'; using the default limits (1 MB to 4 GB, ordered by age)."
	fi

	dbg "machine profile: hostname=$reported_hostname, COMP=$COMP, minsize=$minsize, maxsize=$maxsize, ORDER=$ORDER"
}
