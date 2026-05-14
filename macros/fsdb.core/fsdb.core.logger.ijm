//fsdb-rev-date: 240430
// this macro is systematically logging the output of the macros, which are calling it
// it expects a (multiword) string in which the last word is the basename of the log-file.
// example from a macro using this macro:
// runMacro([this macro], string); 
// where 'string' is "this is a comment to be logged. /tmp/thisLog.txt"

// if dbg>0 this macro also writes all output into a common file called 'debugger' 
// at getDirectory("imagej")+"../../logs"


dbg=0; // debugging; active, when greater that 0
//dbgName="debug";
fs=File.separator;

// get string of parameters
string=getArgument();
// if no parameters are provided, place a hyphen as string
if(lengthOf(string) == 0){
	string="-";
}
//print(string);

// split the string of parameters into an array (along the white-spaces)
stringArray=split(string, " ");
// per definition the log-file to write to (LOG) is the last element of the array of parameters
LOG=stringArray[lengthOf(stringArray)-1];
// the rest of the string of parameters is the text for the log-entry (outString).
outString=replace(string, LOG, "");
print(outString);
// write the outString to the log-file
if (File.exists(LOG) == 0){
	FID=File.open(LOG);
	print(FID, outString);
	File.close(FID);
}
File.append(outString, LOG);

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);
//if (dbg > 0) {print(dbgName+" test_tog:", test_tog); }

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
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
	MAKEDIR_FMAC=COREMACROS+"/fsdb.core.makeDirRecursively.ijm";
	LOGdir=FIJIDIR+"/../../logs";
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
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
	MAKEDIR_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.makedir", COREMACROS+"/fsdb.core.makeDirRecursively.ijm");
	LOGdir=call("ij.Prefs.get", "fsdb.fsdb.dir.logdir", FIJIDIR+"/../../logs"); 
}

// additionally (and optionally) to the the output to the log-file this macro 
// can also write all output to a common file, which in some cases facilitates 
// debugging (all infos in the same place). For this to happen 'dbg' has to be 
// set >0
if (dbg > 0){
// define and optionally create output directory	
	//LOGdir=call("ij.Prefs.get", "fsdb.fsdb.dir.logdir", getDirectory("imagej")+"../../logs");
	LOGdir=File.getDirectory(LOG);
	if (File.isDirectory(LOGdir) == 0 ){
		// recursivly generate directory for LOG-file
		LOGdir=replace(LOGdir, fs, "/");
		runMacro(MAKEDIR_FMAC, LOGdir);

	}
// define output file ('debugger')	
	centralLOG=LOGdir+"/debugger";
// write entrie string of parameters to 'debugger' 
	if (File.exists(centralLOG)){
		File.append(string, centralLOG); 
	} else {
		FID=File.open(centralLOG);
		print(FID, string);
		File.close(FID);
	}
}

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}
