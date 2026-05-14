#!/bin/bash
<<README
This script is setting up smb 

It is NOT dealing with greating users nor their passwords, because this is done by makeAccounts.sh . 
README

#fsdb-rev-date: 251023

function fail(){
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

## ======
## FUNCTION CALLS
## ======

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# get variables of fsdb from getVar.sh
if ! source getVar; then
	dir=$thisDir 
	for _ in $(seq 1 4); do
		GV=$(find "$dir" -name "getVar.sh" -print -quit)
		if [[ -f $GV ]]; then 
			source "${GV}"
			break 
		else
			dir="$(dirname "$dir")"
		fi
	done
	if [[ ! -f "${GV}" ]]; then
		echo "ERROR: Can't find getVar.sh"
		exit 555
	fi
fi
intro $(basename $0)

#debug=2

# install smb
sudo apt install -y samba 
dbg "samba installed"


TMPCONF=$TEMPLATESDIR/smb.conf.fsdb.bup$D
# import and adjust smb.conf
# populate the 'hosts allow' in smb.conf from 'HOSTS' in .SCRIPTS.CONFIG
# These computers are granted access for remote maintenance.
cat $TEMPLATESDIR/smb.conf.stat |sed "s@hosts allow = .*@hosts allow = $HOSTS@" >$TMPCONF

dbg $(grep "hosts allow" $TMPCONF)

while read line; do 
	if [[ $(echo $line |grep -c "^#") -gt 0 ]]; then
		echo "$line"
	else
		eval echo "$line"
	fi
done < $TEMPLATESDIR/smb.conf.flex >>$TMPCONF

# copy smb.conf.fsdb$D to /etc/samba/smb.conf - backup exiting one
backup /etc/samba/smb.conf
cp $TMPCONF /etc/samba/smb.conf
dbg "smb configured"

dbg "restarting samba"
/etc/init.d/smbd restart

# potentially the local firewall needs to be modified
# If you have a firewall running on your Ubuntu system you'll need to allow 
# incoming UDP connections on ports 137 and 138 and 
# TCP connections on ports 139 and 445.
#sudo ufw allow 'Samba'