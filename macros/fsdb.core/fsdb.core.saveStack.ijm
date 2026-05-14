/*
This macro saves the active image as tif, nrrd or single-channel-nrrd 

It expects no parameters
*/
//fsdb-rev-date: 241211

dbgName="saveStack";
dbg=0; // debugging; active, when greater that 0
interactive=0; // stops at stop-points and waits for the user when 1 
ic=0; // interactive-counter for numbering the debugging output
var IID="";
var suff="";
fs=File.separator;

splitChannels=1;

if (dbg >1 ){
	print("\\Clear");
}

//=======================
// variable definition
//=======================

if (dbg > 0) { print("::"+dbgName); }

//outFt=getArgument();
suff=getArgument();

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
//test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

if (test_tog == 1) {
	if (dbg > 0) { print(dbgName+": test-mode"); }
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR="/home/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//		//fn=replace(fn, "//wsl.localhost/Ubuntu-22.04", "");
//	} else {
//		FIJIDIR="C:/Users/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//	}	
// import necessary variables into fiji
	MACROSDIR=FIJIDIR+"/macros";
	COREMACROS=MACROSDIR+"/fsdb.core";
	SECDATAMACROS=MACROSDIR+"/fsdb.sdg";
// get connected macros 
	INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
	MAKEDIR_FMAC=COREMACROS+"/fsdb.core.makeDirRecursively.ijm"; 
	DISSECTNAME_FMAC=COREMACROS+"/fsdb.core.dissectFilename.ijm";
// get environment for logging
	LOGdir=FIJIDIR+"../../logs";
} else {
	if (dbg > 0) { print(dbgName+": production-mode"); }
// get all varables defined in the .scripts.config of the fsdb
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR=getDirectory("imagej");
//	} else {
//		FIJIDIR=File.getDirectory(getInfo("ij.executable"));
//	}
	// import fsdb-variables into fiji
	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", FIJIDIR+"/macros/fsdb.core/fsdb.core.initFsdb.ijm"); 
	runMacro(INITFSDB_FMAC);
// import necessary variables into fiji
	MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", FIJIDIR+"/macros");
	COREMACROS=call("ij.Prefs.get", "fsdb.core.dir.coremacros", MACROSDIR+"/fsdb.core");
	SECDATAMACROS=call("ij.Prefs.get", "fsdb.core.dir.secdatamacros", MACROSDIR+"/fsdb.sdg");
// get connected macros
	INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+"/fsdb.core.initLOG.ijm");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
	MAKEDIR_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.makedir", COREMACROS+"/fsdb.core.makeDirRecursively.ijm"); 
	DISSECTNAME_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.dissectname", COREMACROS+"/fsdb.core.dissectFilename.ijm");
// get environment for logging
	LOGdir=call("ij.Prefs.get", "fsdb.fsdb.dir.logdir", FIJIDIR+"../../logs");
}
// get toggles and variables 
SECDATA_EXT=call("ij.Prefs.get", "fsdb.sdg.ext.secdata", "-secData");

// prepare parameters for logging
LOG=runMacro(INITLOG_FMAC, dbgName);

if (nImages == 0){
	if (interactive == 1){
		waitForUser("Open image", "No image detected. Please hit OK and select on from your file system.");
		open();
		IID=getImageID();
	} else {
		debugger("No Image open. Exiting.", LOG);
		exit();
	}
} else {
// set globally used/defined variables
	IID=call("ij.Prefs.get", "fsdb.sdg.stack.id", getImageID());
}

debugger("start", LOG);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
//==== fsdb-end ====

//=======================
// main
//=======================
mode="stack";
title=call("ij.Prefs.get", "fsdb.core."+mode+".title", getTitle());
ft=call("ij.Prefs.get", "fsdb.core."+mode+".ft", replace(title, ".*\\.", ""));
bn=call("ij.Prefs.get", "fsdb.core."+mode+".bn", replace(title, "."+ft, ""));
imgDir=call("ij.Prefs.get", "fsdb.core."+mode+".dir", getDirectory("image")); 
SDDIR=call("ij.Prefs.get", "fsdb.core."+mode+".outdir", imgDir+"/"+bn+SECDATA_EXT); 
outFt=call("ij.Prefs.get", "fsdb.core.tmp.outFt", "");


debugger("bn: "+bn, LOG);
debugger("suff: "+suff, LOG);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
saveStack(outFt);

//=======================
// function definitions
//=======================

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

function saveStack(ft){
	debugger("saveStack", LOG);
	outName=bn+suff;
	//rename(outName);
	if (ft == "nrrd"){
		run("Duplicate...", "title=nrrd duplicate");
		iid=getImageID();
		if ( splitChannels == 0 ){
// save cropped stack as compressed nrrd
			outPath=SDDIR+"/"+outName+".nrrd";
			run("Compressed Nrrd ... ", "save="+outPath);
			debugger(outPath+" saved.", LOG);
		} else {
// save cropped channels as individually compressed nrrd
			getDimensions(width, height, channels, slices, frames);
			tmptit=getTitle();
			//print(iid, getTitle()); // for debugging
			run("Split Channels");
			for (i = 1; i <= channels; i++) {
				selectImage(iid-i);
				ch=replace(getTitle(),"nrrd.*", "");
				outPath=SDDIR+"/"+ch+outName+".nrrd";
				debugger("saving "+outPath, LOG);
				run("Compressed Nrrd ... ", "save="+outPath);
				close();
			}
		}
	}
	if (ft == "tif"){
		outPath=SDDIR+"/"+outName+".tif";
		saveAs("Tiff", outPath);
		debugger( outPath+" saved.", LOG);
	}
	call("ij.Prefs.set", "fsdb.sdg.sample.path", outPath);
	debugger("sample.path: "+outPath, LOG);
//	run("Close All"); //cleanup; close all open images.
}