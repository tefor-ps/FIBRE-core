//fsdb-rev-date: 251211
/*
 this macro initializes the log file of the calling macro. 
 it expects the basename of the log file as a parameter.
 it creates the needed folder structure and prepares the log file for usage.
 
 !!! DO NOT implement the default debbuger into this as is will break everything 
 due to the lack of LOG during the procedure. 
*/

LOGbn=getArgument();
dbg=0; // debugging; active, when greater than 0
dbgName="initLOG";
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//print(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
TS=substring(year,2,4)+IJ.pad(month+1, 2)+IJ.pad(dayOfMonth,2);

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

myPath=getInfo("macro.filepath");
//print(myPath);
pArr=split(myPath, "/");
for (i = 0; i < lengthOf(pArr); i++) {
	if (matches(pArr[i], "fsdb..") == 1) {
		FSDBVERSION=pArr[i];
	}
}
FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
//print("FSDBDIR:", FSDBDIR);

if (dbg > 0) { print("A"); }
COREMACROS=FSDBDIR+"/fsdb-core/macros/fsdb.core/";
INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
LOGdir=FIJIDIR+"/logs";
D=TS;

if (dbg > 0) { print("FSDBDIR:", FSDBDIR, "\nFIJIDIR:", FIJIDIR, "\nCOREMACROS:", COREMACROS, "\nDEBUG_FMAC:", DEBUG_FMAC); }

if (dbg > 1) { print("LOGdir:",LOGdir); }

LOG=initLOG();
return LOG;

function debugger(str, LOG){ // DO NOT USE IN THIS MACRO
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

//==== fsdb-end ====

function initLOG(){
	if (dbg > 0)
		if (dbg > 0) { print("initLOG", D); }
	
	if(File.isDirectory(LOGdir) == 0) {
// recursivly generate directory for LOG-file
		if (dbg > 0) {
			print("making",LOGdir);
			makeDirRecursively(LOGdir);
		}	
	}
// thanks to windows backslashes have to removed from the path
	LOG=replace(LOGdir+"/"+D+"."+LOGbn+".log", "\\", "/");
// for compatibility reasons make sure, that the right file.separator is implemented (backslashes for windows).	
	//print(LOG);
// if log-file doesn't exist, yet, initialize it.	
	if (File.exists(LOG) == 0 ){
		l=File.open(LOG);
		File.close(l);
		if (dbg > 0)
			print(l);
	}
	LOG=toString(LOG);
	if (dbg > 0) { print(LOG); }
	return LOG;
}

function makeDirRecursively(dir){
	if (dbg > 0) { print("makeDir: "+dir); }
	if (File.exists(dir)) {
		if (dbg > 0) { print(dir+" already exists"); }
		d=1;
	} else {
	// recursivly generate directory 	
		dirArray=split(dir, "/");
		if (dbg > 0) { Array.print(dirArray); }
		//waitForUser;
// fluff
		//print(dir+" is "+lengthOf(dirArray)+" layers deep");
// format path of LOGdir	
		if (matches(dirArray[0], "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")) {
			if (dbg > 0)
				print("IP-adress detected: prefixing two slashes");
			path="//"+dirArray[0]; // prefix TWO slashes to IP-adresses
		} else if (matches (dirArray[0], "[A-Z]\:.*")) {
			if (dbg > 0)
				print("windows drive detected: no prefix");
			path=dirArray[0];
		} else {
			if (dbg > 0)
				print("string detected: prefixing one slash");
			path="/"+dirArray[0];
		}
// create directories recursively as far as they don't exist, yet.	
		for (i=1; i<lengthOf(dirArray); i++){
			path=path+"/"+dirArray[i];
			if (dbg > 0)
				print(path);
			//waitForUser;
			if (File.exists(path) == 0) {
				if (dbg > 0)
					print("\\Update:"+path+" <-- new");
				File.makeDirectory(path);
			}
		}
	}
}
