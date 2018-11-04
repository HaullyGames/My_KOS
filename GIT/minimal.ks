@lazyglobal off.

switch to 0.

LOCAL includeList IS LIST().

includeList:add("lib_ui").
includeList:add("lib_parts").
includeList:add("lib_util").
includeList:add("node.ks").
includeList:add("warp").
includeList:add("lib_staging").

DECLARE FUNCTION includeFile {
  PARAMETER fileName.

  FOR f IN includeList {
    if(fileName:CONTAINS(f)) {
      //PRINT("Copying " + fileName).
      RETURN True.
    }
  }

  RETURN False.
}

declare function compileCopy {
  parameter f.
  parameter dir is "".

  //compile(f:name).
  //local ksm is open(f:name:replace(".ks", ".ksm")).
  //if ksm:size < f:size {
  //  copyFiles:add(dir + ksm:name).
  //  return ksm:size.
  //} else {
    copyFiles:add(dir + f:name).
    return f:size.
  //}
}

LOCAL copyFiles IS LIST().
LOCAL libs IS LIST().
LOCAL fls IS LIST().

LIST FILES IN fls.
LOCAL fSize IS 0.
FOR f IN fls {
  IF f:NAME:ENDSWITH(".ks") {
    DELETEPATH("1:" + f:NAME).
    DELETEPATH("1:" + f:NAME:REPLACE(".ks", ".ksm")).
    IF includeFile(f:NAME) {
      SET fSize to fSize + compileCopy(f).
    }
  }
}
CD("lib").
LIST FILES IN libs.
FOR f IN libs {
  IF f:NAME:ENDSWITH(".ks") {
    DELETEPATH("1:/lib/" + f:NAME).
    DELETEPATH("1:/lib/" + f:NAME:REPLACE(".ks", ".ksm")).
    IF includeFile("lib/" + f:NAME) {
      SET fSize to fSize + compileCopy(f, "lib/").
    }
  }
}
CD("..").
IF NOT (DEFINED copyFilesOK) GLOBAL copyFilesOK IS True.
IF core:volume:freespace > fSize {
  SET copyFilesOk TO True.
  IF NOT EXISTS("1:/lib") CREATEDIR("1:/lib").
  FOR f IN copyFiles {
    IF NOT COPYPATH("0:/" + f, "1:/" + f) { SET copyFilesOk TO False. }.
  }
} ELSE {
  print("Core volume too small.").
  print("Need " + (fSize - core:volume:freespace) + " more bytes.").
}
