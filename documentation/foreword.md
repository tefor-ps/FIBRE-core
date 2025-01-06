# fsdb - file system based database

The fsdb organizes the transfer and management of (multidimensional) image data sets from their image acquisition machines (IAS) to the centralized storage server. It can be run directly on the storage server (if it is strong enough) or on a separate compute server, which is connected to the storeage server. 

Following our own need and that of our collaborators (our focus lies on heavy image data like collections 3D confocal stacks) we developed the fsdb as a hands-off data management system for heavy image data. 

Our solution for accessibility of big data is based on __secondary data__, which represent the original data in the form of small (light-weight) derivatives.   

The fsdb is organizing the raw data together with their secondary data strictly by file name in a well structured automatically generated file tree structure. This allows access to all data without a database-specific tools and facilitates working/screening/analyzing of the data with any tool of choice.

The structure of the file system used by the fsdb is defined in the .scripts.config file, which is dynamically generated  in the fsdb's scripts directory. A more detailed description of this file can be found in the dedicated documentation [below](#scriptsconfig).

Documentation on the actions of the shell-scripts of the fsdb are included into a README-section at the head of each of them. An excerpt of these sections can be found [below](#file-specific-documentation-for-the-fsdb).
