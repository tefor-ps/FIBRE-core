dir=getDirectory("Select the fsdb root-directory");	
dir=replace(dir,"\\","/");
//print(dir);

tf=getDirectory("home")+"/tmp";
File.delete(tf);

listFiles(dir, "config");
configs=split(File.openAsString(tf),"\n");
Array.print(configs);

// create dialog for the selection of the configuration file to be modified.
Dialog.create("Modify fsdb configuration");
Dialog.addMessage("configs in "+dir);
Dialog.addChoice("config:", configs);
Dialog.addCheckbox("verbose:", 0);
Dialog.show();
config=Dialog.getChoice();
verbose=Dialog.getCheckbox();
print("modifying",config,"verbose:",verbose);

// dissect config file name
cbn=split(config, "/");
cbn=cbn[lengthOf(cbn)-1];
ccn=split(cbn, ".");
ccn=ccn[0];

// read in config and populate array
str=File.openAsString(config);
strArr=split(str, "\n");
Array.print(strArr);

// define temporary (output) file 
out=getDirectory("temp")+ccn+".txt";

modConfig(config);

function listFiles(dir, suff) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			listFiles(""+dir+list[i], suff);
		} else {
			//print("::"+dir+list[i]+"::");
			if (endsWith(list[i], suff)) {
		//		print("o |"+dir+list[i]+"|");
				ts=dir+list[i];
				if (lengthOf(ts) > 0){
					//print("+", ts);
					File.append(ts, tf);
				}
		//	} else {
		//		print("n "+dir+list[i]);
			}
		}
	}
}

function modConfig(config) {
// create dialog with content of config	
	Dialog.create(cbn);
	for (i = 0; i < lengthOf(strArr); i++) {
		//print(lengthOf(strArr[i]));
		if (startsWith(strArr[i], "#")|| lengthOf(strArr[i]) == 0) {
			Dialog.addMessage(strArr[i]);
		} else {
			//print(strArr[i]);
// deconstruct each line into its components: variable name, varaiable value, optional comment
			tmp=split(strArr[i], " ");
			vn=tmp[0]; // variable name
			tmp=replace(strArr[i], vn+" ", "");
			tmp=split(tmp,"#");
			vv=replace(tmp[0]," [ \t]*$", " "); //variable value (surplus/tailing white spaces removed)
			if (lengthOf(tmp) > 1 && verbose > 0) {
				//print(":",tmp[1]);
				Dialog.addMessage(vn+": "+replace(tmp[1],"<--",""));
			}
			Dialog.addString(vn, vv, lengthOf(vv));
			//print(lengthOf(tmp));
		}
	}
	Dialog.show();
// make sure temp output file exists	
	OID=File.open(out);
	File.close(OID);
	for (i = 0; i < lengthOf(strArr); i++) {
		//print(lengthOf(strArr[i]));
		if (startsWith(strArr[i], "#")|| lengthOf(strArr[i]) == 0) {
			File.append(strArr[i], out); // append commented lines as is.
		} else {
			//print(strArr[i]);
			tmp=split(strArr[i], " ");
			vn=tmp[0];
// get input from dialog
			vv=Dialog.getString();
			tmp=replace(strArr[i], vn+" ", "");
			tmp=split(tmp,"#");
// construct output			
			if (lengthOf(tmp) > 1) {
				print(":",tmp[1]);
				string=vn+" "+vv+" # "+tmp[1];
			} else {
				string=vn+" "+vv;
			}
// append output to temporary output file			
			File.append(string, out);
		}
	}
// backup and erase original config file
	File.copy(config, config+".bup");
	File.delete(config);
// overwrite original config with tmpFile
	str=File.openAsRawString(out);
	//print(str);
	c=File.open(config);
	File.close(c);
	File.append(str, config);
}