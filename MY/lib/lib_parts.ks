// events are preferred because there are no restrictions
FUNCTION partsDoEvent {
  PARAMETER module.             // module target
  PARAMETER event.              // what should do?
  PARAMETER qtde.               // how many modules
  PARAMETER field.              // which field defines stats?
  PARAMETER stats IS "".        // modules with status
  PARAMETER tag IS "".          // only parts with tag

  SET event TO "^"+event+"\b".  // match first word
  LOCAL success IS false.
  LOCAL maxStage IS -1.
  IF tag = "" AND (defined stagingMaxStage) SET maxStage TO stagingMaxStage-1. //see lib_staging

  // list of modules
  SET moduleList TO List().
  FOR mT IN SHIP:MODULESNAMED(module) {
    // filter modules with status required
    IF NOT (stats = "") {
      // Get Fields
      SET fields TO mT:ALLFIELDNAMES().
      // Probably a fix module
      IF fields:LENGTH > 0 {
        IF mT:GETFIELD(field) = stats { moduleList:ADD(mT). }
      }
      ELSE {
        moduleList:ADD(mT).
      }
    }
    ELSE {
      moduleList:ADD(mT).
    }
  }

  // clamp qtde
  IF qtde = 0 OR qtde > moduleList:LENGTH {
    SET qtde TO moduleList:LENGTH.
  }

  FOR m IN moduleList {
    IF qtde > 0 {
      SET p TO m:PART.
      IF p:STAGE >= maxStage AND p:tag = tag {
        FOR e IN m:ALLEVENTNAMES() {
          IF e:MATCHESPATTERN(event) {
            m:DOEVENT(e).
            SET success TO true.
            SET qtde TO qtde-1.
          }
        }
      }
    }
  }
  RETURN success.
}

// actions are only accessible if VAB or SPH upgraded enough
FUNCTION partsDoAction {
  PARAMETER module.
  PARAMETER action.
  PARAMETER tag IS "".

  LOCAL success IS false.
  IF Career():CANDOACTIONS {
    SET action TO "^"+action+"\b". // match first word
    LOCAL maxStage IS -1.
    IF tag = "" AND (defined stagingMaxStage)
      SET maxStage TO stagingMaxStage-1. //see lib_staging
    FOR p IN ship:PARTSTAGGED(tag) {
      IF p:STAGE >= maxStage AND p:MODULES:CONTAINS(module) {
        LOCAL m IS p:GETMODULE(module).
        FOR a IN m:ALLACTIONNAMES() {
          IF a:MATCHESPATTERN(action) {
            m:DOACTION(a,True).
            SET success TO true.
          }
        }
      }
    }
  }
  RETURN success.
}

// Extend/Retract antennas
FUNCTION partsAntennas {
  PARAMETER cmd.        // can be extend/retract.
  PARAMETER qtde IS 0.  // how many antennas
  PARAMETER field IS "status".
  PARAMETER tag IS "".

  SET stats TO "".
  // define status target
  IF cmd = "extend" { 
    SET stats TO "Retracted".
  } 
  ELSE IF cmd = "retract" { 
    SET stats TO "Extended".
  } 
  ELSE { 
    PRINT "partsAntennas: Toggle '"+ cmd +"' wasn't found.".
    RETURN. 
  }
  RETURN partsDoEvent("ModuleDeployableAntenna", cmd, qtde, field, stats, tag).
}

// Extend/Retract solar panels
FUNCTION partsSolarPanels {
  PARAMETER cmd.        // can be extend/retract.
  PARAMETER qtde IS 0.  // how many antennas
  PARAMETER field IS "status".
  PARAMETER tag IS "".

  SET stats TO "".
  // define status target
  IF cmd = "extend" { 
    SET stats TO "Retracted".
  } 
  ELSE IF cmd = "retract" { 
    SET stats TO "Extended".
  } 
  ELSE { 
    PRINT "partsAntennas: Toggle '"+ cmd +"' wasn't found.".
    RETURN. 
  }
  RETURN partsDoEvent("ModuleDeployableSolarPanel", cmd, qtde, field, stats, tag).
}

// Deploy Fairing
FUNCTION partsDeployFairings {
  PARAMETER tag IS "".

  SET qtde TO 0.
  SET field TO "".
  SET stats TO "".

  RETURN partsDoEvent("ModuleProceduralFairing", "deploy", qtde, field, stats, tag)
      OR partsDoEvent("ProceduralFairingDecoupler", "jettison", qtde, field, stats, tag).
}

// Deploy/Retract land gear
FUNCTION partsLandGears {
  PARAMETER cmd.        // can be extend/retract.
  PARAMETER field IS "state".
  PARAMETER tag IS "".
  
  SET qtde TO 1.
  SET stats TO "".
  // define status target
  IF cmd = "extend" { 
    SET stats TO "Retracted".
  } 
  ELSE IF cmd = "retract" { 
    SET stats TO "Deployed".
  } 
  ELSE { 
    PRINT "partsAntennas: Toggle '"+ cmd +"' wasn't found.".
    RETURN. 
  }
  RETURN partsDoEvent("ModuleWheelDeployment", cmd, qtde, field, stats, tag).
}

FUNCTION partsGetPartByMod {
  PARAMETER module IS LIST().
  PARAMETER field IS "".              // which field defines stats?
  PARAMETER stats IS "".        // modules with status

  // list of Parts
  SET partList TO List().
  FOR m IN module {
    FOR mTemp IN SHIP:MODULESNAMED(m) {
      // filter modules with status required
      IF NOT (stats = "") {
        // Get Fields
        SET fields TO mTemp:ALLFIELDNAMES().
        // Probably a fix module
        IF fields:LENGTH > 0 {
          IF mTemp:GETFIELD(field) = stats { moduleList:ADD(mTemp). }
        }
        ELSE {
          partList:ADD(mTemp:PART).
        }
      }
      ELSE {
        partList:ADD(mTemp:PART).
      }
    }
  }

  RETURN partList.
}

// Get list of parts in stage
FUNCTION partsInStage {
  PARAMETER moduleFilter   IS LIST().
  PARAMETER resourceFilter IS LIST().

  LOCAL partList IS LIST().
  IF moduleFilter:LENGTH > 0 {
    SET pL TO partsGetPartByMod(moduleFilter).
  }
  ELSE SET pL TO SHIP:PARTS.

  FOR p IN pL {
    SET i TO partList:LENGTH.
    SET inserted TO FALSE.

    FROM {LOCAL x IS 0.} UNTIL x = i STEP {SET x TO x+1.} DO {
      IF partList[x][0] = p:STAGE {
        partList[x]:ADD(p).
        SET inserted TO TRUE.
      }
    }
    IF NOT inserted {
      partList:ADD(LIST()).
      partList[i]:ADD(p:STAGE).
      partList[i]:ADD(p).
    }
  }
  RETURN partList.
}