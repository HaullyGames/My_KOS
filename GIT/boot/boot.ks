// Print informational message.
function bootConsole {
  parameter msg.

  print "T+" + round(time:seconds) + " boot: " + msg.
}

function bootWarning {
  parameter msg.

  print "T+" + round(time:seconds) + " boot: " + msg.
  hudtext(msg, 10, 4, 24, YELLOW, false).
}

//Print system info; wait for all parts to load
CLEARSCREEN.
bootConsole(round(core:volume:freespace/1024, 1) + "/" + round(core:volume:capacity/1024) + " kB free").
WAIT 1.

//Set up volumes
SET HD TO CORE:VOLUME.
SET ARC TO 0.
SET StartupLocalFile TO path(core:volume) + "/startup.ks".
SET Failsafe TO false.

bootConsole("Attemping to connect to KSC...").
IF HOMECONNECTION:ISCONNECTED {
  bootConsole("Connected to KSC, updating...").
  SET ARC TO VOLUME(0).
  SWITCH TO ARC.

  IF EXISTS("ramp") {
    CD ("ramp").
  } ELSE IF EXISTS("kos-ramp") {
    CD ("kos-ramp").
  }

  SET copyFilesOk TO False.
  RUN copyfiles.
  IF NOT copyFilesOK SET Failsafe TO True.
} ELSE {
  bootConsole("No connection to KSC detected.").
  IF EXISTS(StartupLocalFile) {
    bootConsole("Local startup, proceeding.").
  } ELSE {
    bootConsole("RAMP not detected; extend antennas...").
    IF Career():CANDOACTIONS {
      FOR P IN SHIP:PARTS {
        IF P:MODULES:CONTAINS("ModuleDeployableAntenna") {
          LOCAL M IS P:GETMODULE("ModuleDeployableAntenna").
          FOR A IN M:ALLACTIONNAMES() {
            IF A:CONTAINS("Extend") { M:DOACTION(A,True). }
          }
        }
      }
    }
  }
}

LOCAL StartupOk is FALSE.

bootConsole("Looking for remote start script...").
IF HOMECONNECTION:ISCONNECTED {
  LOCAL StartupScript is PATH("0:/start/" + SHIP:NAME).
  IF EXISTS(StartupScript) {
    bootConsole("Copying remote start script").
    SWITCH TO HD.
    copypath(StartupScript, StartupLocalFile).
    StartupOK ON.
  } ELSE {
    PRINT "No startup script found. Run initialize".
  }
} ELSE {
  SWITCH TO HD.
  IF EXISTS(StartupLocalFile) {
    bootConsole("Using local storage.").
    StartupOk ON.
  }
}

IF Failsafe {
  bootWarning("Failsafe mode: run from archive.").
  SWITCH TO ARCHIVE.
} ELSE {
  SWITCH TO HD.
}

runoncepath("lib/lib_autostart").
if(autostartExists()) {
  autostart().
}
ELSE IF StartupOk {
  RUNPATH(StartupLocalFile).
} ELSE {
  bootWarning("Need user input.").
  CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
}
