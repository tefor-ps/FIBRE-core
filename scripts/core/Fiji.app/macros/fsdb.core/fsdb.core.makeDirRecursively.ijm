//fsdb-rev-date: 240430
dir=getArgument();
dbgName="makeDir";
dbg=0; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);
if (dbg > 0) {print(dbgName+" test_tog:", test_tog); }

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

if (test_tog == 1) {
	if (dbg > 0) { print(dbgName+": A"); }
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR="/home/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//		//fn=replace(fn, "//wsl.localhost/Ubuntu-22.04", "");
//	} else {
//		FIJIDIR="C:/Users/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//	}	
// import necessary variables into fiji
	MACROSDIR=FIJIDIR+"/macros";
	COREMACROS=MACROSDIR+"/fsdb.core";
	INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
} else {
	if (dbg > 0) { print("B"); }
// get all varables defined in the .scripts.config of the fsdb
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR=getDirectory("imagej");
//	} else {
//		FIJIDIR=File.getDirectory(getInfo("ij.executable"));
//	}
	// import fsdb-variables into fiji
//	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", COREMACROS+"/fsdb.core.initFsdb.ijm"); 
	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", FIJIDIR+"/macros/fsdb.core/fsdb.core.initFsdb.ijm"); 
	runMacro(INITFSDB_FMAC);
	MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", FIJIDIR+"/macros");
	COREMACROS=call("ij.Prefs.get", "fsdb.core.dir.coremacros", MACROSDIR+"/fsdb.core");
	INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+"/fsdb.core.initLOG.ijm");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
}

// prepare parameters for logging
LOG=runMacro(INITLOG_FMAC, dbgName);

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

debugger("start", LOG);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
//==== fsdb-end ====

debugger(dir, LOG);
if (dir == ""){
	dir=call("ij.Prefs.get", "fsdb.core.stack.outdir", dir); // outDir
}
makeDirRecursively(dir);
debugger("end", LOG);
	
function makeDirRecursively(dir){
	dir=replace(dir, fs, "/");
	debugger(dir, LOG);
	if (File.exists(dir)) {
	debugger(dir+" already exists", LOG);
	} else {
	// recursivly generate directory 	
		dirArray=split(dir, "/");
		Array.print(dirArray);
		debugger("length of Array: "+lengthOf(dirArray), LOG);
		if (matches(dirArray[0], "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")|| matches(dirArray[0], "wsl.localhost")) {
			debugger("IP-adress detected: prefixing two slashes", LOG);
			path="//"+dirArray[0]; // prefix TWO slashes to IP-adresses
		} else if (matches (dirArray[0], "[A-Z]\:.*")) {
			debugger("windows drive detected: no prefix", LOG);
			path=dirArray[0];
		} else {
			debugger("string detected: prefixing one slash", LOG);
			path="/"+dirArray[0];
		}
// create directories recursively as far as they don't exist, yet.	
		for (i=1; i<lengthOf(dirArray); i++){
			path=path+"/"+dirArray[i];
			debugger(path, LOG);
			if (interactive > 0 ) {waitForUser(dbgName+" "+ic, path); ic++;}
			if (File.exists(path) == 0) {
				print("\\Update:"+path+" <-- new");
				File.makeDirectory(path);
			}
		}
	}
}
