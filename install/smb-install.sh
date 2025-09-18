#!/bin/bash
<<README
This script is setting up smb 

It is NOT dealing with greating users nor their passwords, because this is done by makeAccounts.sh . 
README

# set all global variables
thisDir=$(dirname $(realpath $0))
if [[ -z $1 ]]; then
	source $thisDir/../scripts/core/getVar.sh
else 
	source $1/core/getVar.sh
fi


# install smb
sudo apt install -y samba 
dbg "samba installed"


TMPCONF=$MATDIR/smb.conf.fsdb.bup.$D
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




