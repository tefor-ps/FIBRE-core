#!/bin/bash
<<README
This script mounts given microscopes to the server it is running on.

It expects three parameters:
$1 = IP address of the computer to be connected to
$2 = name of the remote directory to be mounted
$3 = mount point on the local system

comments/explanations on the mount command 
from man mount at
https://www.samba.org/~ab/output/htmldocs/manpages-3/mount.cifs.8.html
https://linux.die.net/man/8/mount.cifs

uid=arg
sets the uid that will own all files on the mounted filesystem. It may be specified as either a username or a numeric uid. For mounts to servers which do support the CIFS Unix extensions, such as a properly configured Samba server, the server provides the uid, gid and mode so this parameter should not be specified unless the server and client uid and gid numbering differ. If the server and client are in the same domain (e.g. running winbind or nss_ldap) and the server supports the Unix Extensions then the uid and gid can be retrieved from the server (and uid and gid would not have to be specifed on the mount. For servers which do not support the CIFS Unix extensions, the default uid (and gid) returned on lookup of existing files will be the uid (gid) of the person who executed the mount (root, except when mount.cifs is configured setuid for user mounts) unless the "uid=" (gid) mount option is specified. For the uid (gid) of newly created files and directories, ie files created since the last mount of the server share, the expected uid (gid) is cached as long as the inode remains in memory on the client. Also note that permission checks (authorization checks) on accesses to a file occur at the server, but there are cases in which an administrator may want to restrict at the client as well. For those servers which do not report a uid/gid owner (such as Windows), permissions can also be checked at the client, and a crude form of client side permission checking can be enabled by specifying file_mode and dir_mode on the client. Note that the mount.cifs helper must be at version 1.10 or higher to support specifying the uid (or gid) in non-numeric form.

gid=arg
sets the gid that will own all files on the mounted filesystem. It may be specified as either a groupname or a numeric gid. For other considerations see the description of uid above.

file_mode=arg
If the server does not support the CIFS Unix extensions this overrides the default file mode.

dir_mode=arg
If the server does not support the CIFS Unix extensions this overrides the default mode for directories.

rw
mount read-write

noserverino
Client generates inode numbers itself rather than using the actual ones from the server.
See section INODE NUMBERS for more information.

nounix
Disable the CIFS Unix Extensions for this mount. This can be useful in order to turn off multiple settings at once. This includes POSIX acls, POSIX locks, POSIX paths, symlink support and retrieving uids/gids/mode from the server. This can also be useful to work around a bug in a server that supports Unix Extensions.
See section INODE NUMBERS for more information.

Inode Numbers
When Unix Extensions are enabled, we use the actual inode number provided by the server in response to the POSIX calls as an inode number.

When Unix Extensions are disabled and "serverino" mount option is enabled there is no way to get the server inode number. The client typically maps the server-assigned "UniqueID" onto an inode number.

Note that the UniqueID is a different value from the server inode number. The UniqueID value is unique over the scope of the entire server and is often greater than 2 power 32. This value often makes programs that are not compiled with LFS (Large File Support), to trigger a glibc EOVERFLOW error as this won't fit in the target structure field. It is strongly recommended to compile your programs with LFS support (i.e. with -D_FILE_OFFSET_BITS=64) to prevent this problem. You can also use "noserverino" mount option to generate inode numbers smaller than 2 power 32 on the client. But you may not be able to detect hardlinks properly

#credentials=/root/.smbcredentials,uid=33,gid=33,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0
README

#fsdb-rev-date: 251030

#TODO : wake-on-lan??? (nice-to-have?)

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

function getDriveLetter() {
	read -e -p "Drive letter:" dl
	if [[ -z $dl ]]; then
		warn "Please make sure to enter a valid drive letter."
 		getDriveLetter
 	else
 		dl=$(echo $dl |tr [[:lower:]] [[:upper:]])
 	fi
}

function mountMic(){
	ping -c 3  $1 >/dev/null;
	if [ $(echo $?) -eq 0 ]; then
		sudo mkdir -p $3
		if [[ -f /etc/wsl.conf ]]; then
			warn "You are working within a Windows subsystem for Linux (WSL). This is problematic, because this OS will not be able to mount the hard drives of your microscope directly."
			warn "Please mount the shared drive in your file system explorer first (This PC > Computer > Map Network Drive)."
			warn "Subsequently enter the corresponding drive letter below."
			getDriveLetter
			dbg2 "sudo mount -t drvfs ${dl}: $3"
			#-o vers=2.0,credentials=$AUTHDIR/.cred-$4,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777"
			sudo mount -t drvfs ${dl}: $3 |tee -a $LOG
		else
			dbg2 "sudo mount -t cifs -o vers=2.0,credentials=$AUTHDIR/.cred-$4,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777 //$1/$2 $3"
			#sudo mount -v -t cifs -o vers=2.0,credentials=$AUTHDIR/.cred-$4,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777 //$1/$2 $3 |tee -a $LOG
			sudo mount -t cifs -o vers=2.0,credentials=$AUTHDIR/.cred-$4,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777 //$1/$2 $3 |tee -a $LOG
		fi
	else
		error "$2 is offline"
	fi
}

source $MICS
