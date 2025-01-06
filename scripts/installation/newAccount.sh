#!/bin/bash
<<README
This script creates a new user on the fsdb, put it in the correct groups, and 
sets-up a SMB account so it can access remotly to the labdata folder.
README


usage="$(basename "$0") [-h] [-u acc] [-g x,y,z] -- program to create a new account on the fsdb and set-up a SMB access for it

where :
        -h show this help text
	-u set the username
        -s set the group (coma-separated values if multiple groups required)"



function typePasswd() {
        pass1="1"
        pass2="2"
        while true; do
                read -sp 'Password : ' pass1
                echo
                read -sp 'Password (again) : ' pass2
                echo
                [ "$pass1" = "$pass2" ] && break
                echo "Please try again"
        done
}




while getopts ':hu:g:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    u) account=$OPTARG
       ;;
    g) groups=$OPTARG
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done

# if the mandatory options are empty, exit the script
if [ -z $account ] || [ -z $groups ]; then
	echo "$usage"
	exit 1
fi


echo "Setting-up UNIX account for $account..."
echo

# get the user ID according to the fsdb policy
nextID=$(shuf -i 2000-65000 -n 1)
while [ $( grep -v nobody /etc/passwd |cut -d ":" -f 3 |grep -c $nextID) -gt 0 ];do
        nextID=$(shuf -i 2000-65000 -n 1)
done


# create the account if it does not exist, otherwise update permissions
if [ $(getent passwd |grep -wc $account) -eq 0 ];then

	typePasswd

        useradd -u $nextID -f 120 -U -G $groups -m -s /bin/bash -U $account
        echo "$account:$pass1" | chpasswd
        if [[ $? -ne 0 ]]; then echo "Something went wrong when setting-up the UNIX account; exiting."; exit 1; fi

	echo
	echo "Now setting-up the samba account for $account..."
	echo
	printf "$pass1\n$pass2\n" | smbpasswd -a -s $account

else

	echo "Account $account already exists."
        usermod -a -G $groups $account

fi


exit 0
