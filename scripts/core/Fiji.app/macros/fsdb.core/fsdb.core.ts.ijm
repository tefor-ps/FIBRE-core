//fsdb-rev-date: init240430
dbgName="timestamp";
dbg=0; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);
if (dbg > 0) {print(dbgName+"test_tog:", test_tog); }

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

// get data for timespamp
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
// construct short form of timestamp in the format yymmdd
D=substring(year,2,4)+IJ.pad(month+1, 2)+IJ.pad(dayOfMonth,2);
// construct long form of timestamp for log-file
//TS=substring(year,2,4)+IJ.pad(month+1, 2)+IJ.pad(dayOfMonth,2)+"-"+IJ.pad(hour,2)+":"+IJ.pad(minute,2)+":"+IJ.pad(second,2);
TS=substring(year,2,4)+IJ.pad(month+1, 2)+IJ.pad(dayOfMonth,2)+"-"+IJ.pad(hour,2)+IJ.pad(minute,2)+IJ.pad(second,2);
// append timestamp in long form to the log-file
debugger(TS, LOG);
// echo timestamp
print(TS);

return toString(TS);