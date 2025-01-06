#!/bin/bash

# if xvfb is not installed, yet, install it
if [[ $(which xvfb-run |wc -l) -eq 0 ]]; then
	echo "xvfb is one of the prereguisits and is currently not installed. Installing it now\n"
	sudo apt install -y xvfb
fi

# motivated by:
# http://stackoverflow.com/questions/30332137/xvfb-run-unreliable-when-multiple-instances-invoked-in-parallel
# https://gist.github.com/volkovasystems/f4661b87d44c89275a48631fdabee41d

echo "running xvfb-run-safe" 

# allow settings to be updated via environment
: "${xvfb_lockdir:=$HOME/.xvfb-locks}"
: "${xvfb_display_min:=99}"
: "${xvfb_display_max:=599}"

# assuming only one user will use this, let's put the locks in our own home directory
# avoids vulnerability to symlink attacks.
mkdir -p -- "$xvfb_lockdir" || exit

i=$xvfb_display_min		 						# minimum display number
while (( i < xvfb_display_max )); do
	if [[ -f "/tmp/.X$i-lock" ]]; then			# still avoid an obvious open display
		(( ++i )); continue
	fi
	echo "xvfb display number: $i"
	exec 5>"$xvfb_lockdir/$i" || continue		# open a lockfile
	if flock -x -n 5; then						# try to lock it
		echo "$i $@"
		exec xvfb-run -l -a --server-num="$i" $@ || exit	# if locked, run xvfb-run
	fi
	(( i++ ))
done