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

# find and source getVar.sh to set all global variables
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 || "$1" =~ "-" ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
else
	if [[ -d $1 ]]; then
		gv=$(find "$1" -type f -name getVar.sh)
	else
		gv=$(find $(dirname "$1") -type f -name getVar.sh)
	fi
fi

if [[ -f "$gv" ]]; then
	source "$gv"
else
	echo "ERROR: Can't find getVar.sh"
	exit 555
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