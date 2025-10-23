#!/bin/bash
<<README
This script is generating UNIX user accounts for each user defined in scripts.config (ADMIN, GROUPACCOUNTS, USERACCOUNTS) 

useradd options (from man page)
-G, --groups GROUP1[,GROUP2,...[,GROUPN]]]
           A list of supplementary groups which the user is also a member of. Each group is separated from the next by a comma,
           with no intervening whitespace. The groups are subject to the same restrictions as the group given with the -g option.
           The default is for the user to belong only to the initial group.
-m, --create-home
           Create the user's home directory if it does not exist. The files and directories contained in the skeleton directory
           (which can be defined with the -k option) will be copied to the home directory.
           By default, if this option is not specified and CREATE_HOME is not enabled, no home directories are created.
-u, --uid UID
           The numerical value of the user's ID. This value must be unique, unless the -o option is used. The value must be
           non-negative. The default is to use the smallest ID value greater than or equal to UID_MIN and greater than every other
           user.
           See also the -r option and the UID_MAX description.
-U, --user-group
           Create a group with the same name as the user, and add the user to this group.
-s, --shell SHELL
           The name of the user's login shell. The default is to leave this field blank, which causes the system to select the
           default login shell specified by the SHELL variable in /etc/default/useradd, or an empty string by default.
README

#fsdb-rev-date: 251023

## ======
## FUNCTION DEFINITIONS
## ======

function definePasswd() {
# generate, suggest and set password for user
	miniID=$(getent passwd $account |cut -d ":" -f 3 |tail -c 2)
	inv=$(echo $account|rev); 
	userString=$(echo -n ${inv:0:1} |tr "[:lower:]" "[:upper:]") 
	userString=${userString}$(echo ${inv:1})
	lab=$(echo $LAB |tr "[:lower:]" "[:upper:]")
	suggestion=${lab}\!${miniID}${userString}
	warn "User interaction needed: define password for $account" 
	skipPerm "The fsdb suggests the string ${suggestion} as the password for the account $account" 
	if [[ $skipFlag -eq 0 ]]; then
		thisPass=$suggestion
	else
		thisPass=x
		confirmedPass=y
		warn "User interaction needed: define password for $account" 
		read -s -p "Password for $account (will not show): " thisPass
		read -s -p "Retype password for $account (will not show): " confirmedPass
		while [[ "$thisPass" !=  "$confirmedPass" ]]; do
			error "The passwords do not match. Please try again."
			definePasswd
		done
	fi
	printf "$account:$thisPass\t$D\n" >> $ATTICDIR/fsdb-creds.txt
	echo "$account:$thisPass" | chpasswd
	if [[ $? -eq 0 ]]; then intro "Password changed."; fi
}

function setupSmb(){
# gernerate a samba user and assign the same password as for linux
# note: under LDAP have a look into smbpasswd -w 
	printf "$thisPass\n$thisPass\n" |smbpasswd -a -s $account
}

function fail(){
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

## ======
## FUNCTION CALLS
## ======

# find getVar.sh
thisDir=$(dirname $(realpath "$0"))
if [[ -z $1 ]]; then
	if [[ "$thisDir" =~ /fsdb[0-9]{2}/ ]]; then
		FSDBDIR="$(realpath $thisDir |sed -r 's@(/fsdb[0-9]{2}/).*@\1@')"
	else
		FSDBDIR="$(realpath $thisDir/../..)"
	fi
	gv=$(find "$FSDBDIR" -type f -name getVar.sh)
	#source $thisDir/../scripts/core/getVar.sh
else 
	gv=$(find "$1" -type f -name getVar.sh)
	#source $1/core/getVar.sh
fi

fi [[ -f "$gv" ]]; then
	source "$gv"
else
	fail "Can't find getVar.sh"
fi

# log file for debugging and cleanup
mkdir -p $LOGDIR
echo "logs at $LOGDIR"
LOG="$LOGDIR/$D.$(basename $0 .sh).log"
#if [ -f $LOG ]; then
#	sudo rm $LOG
#fi
date >> $LOG

intro "generating group accounts" |tee -a $LOG
for group in $GROUPACCOUNTS; do
	echo $group 
# avoid using an UID, which is already assigned to another user
        nextID=$(shuf -i 1100-1999 -n 1)
        while [ $( grep -v nobody /etc/passwd |cut -d ":" -f 3 |grep -c $nextID) -gt 0 ];do
                nextID=$(shuf -i 1100-1999 -n 1)
        done
#	if [ $(getent passwd |grep -wc ^${account}:) -eq 0 ];then
	if [ $(getent group |grep -wc ^${group}:) -eq 0 ];then
		if [[ "$group" == $GROUP ]];then
			#create as user & group
			sudo useradd -u $nextID -f 30 -U  -m -s /bin/bash -U $group
		else
			#create as group only
			sudo groupadd -g $nextID -f $group
		fi
# set password for user
     	#definePasswd
	else
		echo "Group $group already exists."
	fi
done
	
intro "generating sysadmin accounts" |tee -a $LOG
thisUID=1000
for account in $ADMIN $ADMINACCOUNTS; do
	if [ $(getent passwd |grep -wc $account) -eq 0 ];then
		while [ $( grep -v nobody /etc/passwd |cut -d ":" -f 3 |grep -c $thisUID) -gt 0 ];do
			thisUID=$[$thisUID+1]
			echo $thisUID
		done
		echo "sudo useradd -u $thisUID -U -G $ADMIN,$CONSORTIUM,$GROUP,sudo -m -s /bin/bash -U $account"
		sudo useradd -u $thisUID -U -G $ADMIN,$CONSORTIUM,$GROUP,sudo -m -s /bin/bash -U $account
# set password for user
     	definePasswd
	else
		echo "Account $account already exists."
		sudo usermod -a -G $ADMIN,$CONSORTIUM,$GROUP,sudo $account
	fi
	setupSmb
done

intro "generating user accounts" |tee -a $LOG
for account in $USERACCOUNTS $GROUP; do
	echo $account
# avoid using an UID, which is already assigned to another user
	nextID=$(shuf -i 2000-65000 -n 1)
	while [ $( grep -v nobody /etc/passwd |cut -d ":" -f 3 |grep -c $nextID) -gt 0 ];do
		nextID=$(shuf -i 2000-65000 -n 1)
	done 
	if [ $(getent passwd |grep -wc $account) -eq 0 ];then
		sudo useradd -u $nextID -f 120 -U -G $CONSORTIUM,$GROUP -m -s /bin/bash -U $account 
# set password for user
		definePasswd
	else
		echo "Account $account already exists."
		sudo usermod -a -G $CONSORTIUM,$GROUP $account 
	fi
	setupSmb
done

intro "generating developer accounts" |tee -a $LOG
for account in $DEVACCOUNTS; do
	echo $account
# avoid using an UID, which is already assigned to another user
	nextID=$(shuf -i 2000-65000 -n 1)
	while [ $( grep -v nobody /etc/passwd |cut -d ":" -f 3 |grep -c $nextID) -gt 0 ];do
		nextID=$(shuf -i 2000-65000 -n 1)
	done 
	if [ $(getent passwd |grep -wc $account) -eq 0 ];then
		sudo useradd -u $nextID -f 120 -U -G $DEV  -m -s /bin/bash -U $account 
# set password for user
		definePasswd
	else
		echo "Account $account already exists."
		sudo usermod -a -G $DEV $account 
	fi
	setupSmb
done

cat /etc/passwd

