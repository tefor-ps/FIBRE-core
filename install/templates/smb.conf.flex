
# ===================================================================
# PROTECTED DATA
# root access to the dir-tree; for admin only
# everything in $STORAGEDIR/ is not supposed to be directly accessible to 
# the user.
[root]
   comment = location for raw data
   path = $DATAROOT
   browseable = yes
   valid users = @$ADMIN
   create mask = 0770
   directory mask = 0770
   guest ok = no
   read only = no

# scripts and macros for tefor; written/edited by tefor/teforadmin; 
# executed by tefor as robot/cron-job
[scripts]
   comment = Tefor code
   path = $SCRIPTSDIR
   browsable = yes
   valid users = @$ADMIN,@$DEV
   create mask = 0750
   directory mask = 0750
   force group = $DEV
   guest ok = no
   read only = no

   # static data share.    
[${LAB}-archive]
   comment = place for recyclable data
   path = $ARCHIVEDIR
   browsable = yes
   valid users = @$GROUP,@$ADMIN
   guest ok = no
   read only = yes
   create mask = 0750
   directory mask = 0750
   force group = $ADMIN

# ===================================================================
# LAB-ACCESSIBLE DATA
# root of the data layer, which is freely accessible to $LAB members
[${LAB}-data]
   path = $LABDATADIR
   valid users = @$GROUP,@$ADMIN
   guest ok = no
   browsable = yes
   read only = no
   create mask = 0770
   directory mask = 0770
   force group = $LAB
   force create mode = 0770
   force directory mode = 0770
   follow symlinks = yes

# temporary data share. data will be expunged automatically after 6 weeks  
[${LAB}-exchange]
   comment = local data exchange folder
   path = $EXCHANGEDIR
   browsable = yes
   valid users = @$ADMIN,@$GROUP
   create mask = 0770
   directory mask = 0770
   force group = $LAB
   guest ok = no
   read only = no

# temporary data share. data will be expunged automatically after 6 weeks  
[${CONSORTIUM}-export]
   comment = local data exchange folder
   path = $EXPORTDIR
   browsable = yes
   valid users = @$ADMIN,@$GROUP,@$CONSORTIUM
   create mask = 0770
   directory mask = 0770
   force group = $LAB
   guest ok = no
   read only = no
   
