//fsdb-rev-date: 240430
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

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);
if (dbg > 0) {print(dbgName+" test_tog:", test_tog); }

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//print(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
TS=substring(year,2,4)+IJ.pad(month+1, 2)+IJ.pad(dayOfMonth,2);

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

if (test_tog == 1) {
	if (dbg > 0) { print("A"); }
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR="/home/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//		//fn=replace(fn, "//wsl.localhost/Ubuntu-22.04", "");
//	} else {
//		FIJIDIR="C:/Users/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//	}	
	MACROSDIR=FIJIDIR+"/macros";
	COREMACROS=MACROSDIR+"/fsdb.core";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
	LOGdir=FIJIDIR+"/../../logs";
	D=TS;
	//call("ij.Prefs.set", "fsdb.getVar.static.d", D);
} else {
	if (dbg > 0) { print("B"); }
// get all varables defined in the .scripts.config of the fsdb
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR=getDirectory("imagej");
//	} else {
//		FIJIDIR=File.getDirectory(getInfo("ij.executable"));
//	}
	MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", FIJIDIR+"/macros");
	COREMACROS=call("ij.Prefs.get", "fsdb.core.dir.coremacros", MACROSDIR+"/fsdb.core");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
	LOGdir=call("ij.Prefs.get", "fsdb.fsdb.dir.logdir", FIJIDIR+"/../../logs"); 
	D=call("ij.Prefs.get", "fsdb.getVar.static.d", TS);
	// import fsdb-variables into fiji
	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", COREMACROS+"/fsdb.core.initFsdb.ijm"); 
	runMacro(INITFSDB_FMAC);	
}

FIJIDIR=replace(FIJIDIR, fs, "/");

if (dbg > 0) { print(FIJIDIR, "\n", MACROSDIR, "\n", COREMACROS, "\n", DEBUG_FMAC); }

if (dbg > 0) { print("LOGdir",LOGdir); }

LOG=initLOG();
return LOG;

function debugger(str, LOG){ // DO NOT USE, HERE
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
