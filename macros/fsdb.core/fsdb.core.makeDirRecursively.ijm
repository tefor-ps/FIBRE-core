//fsdb-rev-date: 260115

if (getArgument() == "") {
	title=getTitle();
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
	dir=getDirectory("image");
	outPath=dir+"/"+bn+"-secData/"+bn+".nrrd";
} else {
	outPath=getArgument();
}

dbgName="makeDir";
dbg=1; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

//myPath=getInfo("macro.filepath");
myPath=getDirectory("current");
print(myPath);
pArr=split(myPath, "/");
for (i = 0; i < lengthOf(pArr); i++) {
	if (matches(pArr[i], "fsdb..") == 1) {
		FSDBVERSION=pArr[i];
		FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
	} else {
		FSDBDIR=myPath+"/../../../";
	}
}
FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
print(FSDBDIR);

if (dbg > 0) { print(dbgName+": A"); }
COREMACROS=FSDBDIR+"/fsdb-core/macros/fsdb.core/";
INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";

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

debugger(outPath , LOG);
makeDirRecurively(outPath); 
debugger("end", LOG);

function makeDirRecurively(dir) {
	list = split(dir, "/");
	path="";
	for (i=0; i<list.length; i++) {
		if(i == list.length-1 && matches(list[i], ".*\\..*") == 1){
			print(list[i]+" is a file");
		} else {
			path=path+"/"+list[i];
			if (File.exists(path) == 0) {
				File.makeDirectory(path);
				print("Created "+path);
			}
		}
	}
}