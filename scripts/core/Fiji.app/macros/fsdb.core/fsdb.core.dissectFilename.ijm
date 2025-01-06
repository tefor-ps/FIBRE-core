/*
 * This macro divides filenames into their components and stores the in corresponding ij.Prefs
 * 
 * This macro can take two parameters:
 * - the first parameter can take the keywords "stack" or "tmp" or a filename
 *   If a keyword is provided, it is used to define the ij.Prefs in the form of 
 *   ij.Prefs.[keyword].[variable]
 *   Default="tmp"
 * - the second parameter is the filname (when the first is a keyword).
 *
 * Is no parameter given, the filename is taken from the active image via getTitle();
 */
//fsdb-rev-date: 241017

param=getArgument();
dbgName="dissectFilename";
dbg=1; // debugging; active, when greater than 0
interactive=0;
ic=0; // interactive-counter for nunmbering the debugging output

if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
//test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

if (test_tog == 1) {
	if (dbg > 0) { print(dbgName+": test-mode"); }
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR="/home/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//		fn=replace(fn, "//wsl.localhost/Ubuntu-22.04", "");
//	} else {
//		FIJIDIR="C:/Users/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//	}	
// import necessary variables into fiji
	MACROSDIR=FIJIDIR+"/macros";
	COREMACROS=MACROSDIR+"/fsdb.core";
	SECDATAMACROS=MACROSDIR+"/fsdb.sdg";
	SECDATA_EXT="-secData";
// get connected macros 
	INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
	MAKEDIR_FMAC=COREMACROS+"/fsdb.core.makeDirRecursively.ijm"; 
	INITFSDB_FMAC=FIJIDIR+"/macros/fsdb.core/fsdb.core.initFsdb.ijm"; 

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
	SECDATA_EXT=call("ij.Prefs.get", "fsdb.sdg.ext.secdata", "-secData");
// get connected macros
	INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+"/fsdb.core.initLOG.ijm");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
	MAKEDIR_FMAC=call("ij.Prefs.set", "fsdb.core.fmac.makedir", COREMACROS+"/fsdb.core.makeDirRecursively.ijm"); 
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


// digest potenially received parameters (getArgument).
param=split(param, "|");								// turn values into array.
//Array.print(param);
debugger("length of param: "+lengthOf(param), LOG);
if (lengthOf(param) == 0) {								// default mode="tmp"; default fn="";
	mode="tmp";
	fn="";
} else {												// if param is not empty,
	debugger("param[0]: "+param[0], LOG);
	if(param[0] == "stack" || param[0] == "tmp"){		// and the param[0] is a mode-keyword, assing it to mode;
		mode=param[0];
		if(lengthOf(param) > 1) {						// if the second parameter is not empty
			fn=param[1];								// take it as fn.
		} else {
			fn="";
		}
	} else {
		mode="tmp";										// otherwise take param[0] as fn and set mode="tmp";
		fn=param[0];
	}
}
debugger("fn: "+fn, LOG);
debugger("mode: "+mode, LOG);

// collect all filetype-suffixes defined in INITFSDB_FMAC 
list=File.openAsString(INITFSDB_FMAC);					// read in INITFSDB_FMAC as string.
arr=split(list, "\n");									// split string into lines.
//Array.print(arr);
ftArr=newArray("");
for (i = 0; i < lengthOf(arr); i++) {					// for each line,
	if(matches(arr[i], ".*.ft..*")){						// select all lines which contain the string _FT (for filetype),
		//debugger(arr[i], LOG);
		tmp=split(arr[i], " ");							// break the resulting lines into words.
		res=replace(tmp[2], "[\;\)\"]", "");			// remove unwanted characters from third word.
		//debugger(res, LOG);
		if(startsWith(res, ".") == 0){ res="."+res; }	// makes sure all resulting words (suffixes) start with a dot.
// store results in an array
		if(ftArr[0] == "") {
			ftArr[0]=res;								// the first result explicitly goes into first position; 
		} else {
			match=0;									// the others subsequently are appended - as long as are unique.
			for (j = 0; j < lengthOf(ftArr); j++) {
				if(matches(ftArr[j], res)) {
					match=1;							// (if a word is already in ftArr, don't add it again)
				}				
			}
			if(match == 0){
				ftArr=Array.concat(ftArr,res);			// only if the word is not yet in ftArr add it to ftArr.
			}
			//Array.print(ftArr);
		}
	}
}
//debugger(lengthOf(ftArr), LOG);
Array.sort(ftArr);
//Array.print(ftArr);

// get stack modalities from INITFSDB_FMAC to define end of bn properly
modArr=newArray("");
for (i = 0; i < lengthOf(arr); i++) {
	if(matches(arr[i], ".*modality.*")){
		//print(arr[i]);
		tmp=split(arr[i], ";");
		tmp=split(tmp[0], ",");
		res=replace(replace(tmp[2], ")", ""), "\"","");
		//print(res);
// store results in an array
		if(modArr[0] == "") {
			modArr[0]=res;								// the first result explicitly goes into first position; 
		} else {
			modArr=Array.concat(modArr,res);
		}
	}
}
//Array.print(modArr);

// decide to work with a provided filename (fn) or getTitle.
if (fn == ""){
	title=replace(replace(getTitle(), fs, "/"),".*/","");
	rename(title);
} else {
	title=replace(replace(fn, fs, "/"),".*/","");
}
bn=replace(title, "\\..*", "");
for (i = 0; i < lengthOf(modArr); i++) {
	modality=replace(modArr[i], " ", "");
	repl=replace(modality+".*", " ", "");
	bn=replace(bn, repl, modality);
}	
debugger("title: "+title, LOG);
debugger("bn: "+bn, LOG);

// ensure, that the last dot-separated element of the filename is indeed a 
// filetype-suffix known by the fsdb by comparing it to the suffixes extracted 
// above.
ft="";
tmpft=replace(title, ".*\\.", "");
debugger(tmpft, LOG);
match=0;
for (i = 0; i < lengthOf(ftArr); i++) {
	print(ftArr[i]);
	if(matches("."+tmpft, ftArr[i])){					// if the last element of the input filename is a known filetype suffix,
		ft=ftArr[i];									// keep it as ft
		match=1;
		break;											// and end this loop
	}
}
if (match == 0 ){
	print(title+" is not a file-type recognized by the fsdb. Exiting.");
	return toString(1);
	exit;
}

// extract suffix by removing ft and bn from title
suff=replace(replace(title, bn, ""), ft, "");

// export variables to ij.Prefs
//print(dbgName, mode+".title: "+title);
debugger(mode+".title: "+title, LOG);
call("ij.Prefs.set", "fsdb.core."+mode+".title", title); // STACK_TITLE 
//print(dbgName, mode+".bn: "+bn);
debugger(mode+".bn: "+bn, LOG);
call("ij.Prefs.set", "fsdb.core."+mode+".bn", bn); // STACK_BN 
//print(dbgName, mode+".ft: "+ft);
debugger(mode+".ft: "+ft, LOG);
call("ij.Prefs.set", "fsdb.core."+mode+".ft", ft); // STACK_FT 
//print(dbgName, mode+".suff: "+suff);
debugger(mode+".suff: "+suff, LOG);
call("ij.Prefs.set", "fsdb.core."+mode+".suff", suff); // STACK_SUFF 

// get image location and construct output location
if (fn != ""){
	selectImage(fn);
}
dir=replace(getInfo("image.directory"), fs, "/");
call("ij.Prefs.set", "fsdb.core."+mode+".dir", dir); // STACK_DIR
print(dbgName, mode+".dir: "+dir);
if(matches(dir, ".*"+SECDATA_EXT+".*")){
	outDir=dir;
} else {
	outDir=dir+"/"+bn+SECDATA_EXT+"/";
}
call("ij.Prefs.set", "fsdb.core."+mode+".outdir", outDir); // outDir
print(dbgName, mode+".outdir: "+outDir);
//runMacro(MAKEDIR_FMAC, outDir);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
return toString(0);