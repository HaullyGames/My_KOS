// Get science availables
// Testing
FUNCTION getScienceList {
  LOCAL success IS false.

  // list of modules
  SET moduleList TO List().
  FOR mT IN SHIP:MODULESNAMED("ModuleScienceExperiment") {
    // filter modules with status required
    IF NOT (mT:INOPERABLE) {
      moduleList:ADD(mT).
      PRINT " ".
      PRINT mt:PART:NAME.
      PRINT mt:RERUNNABLE.
      PRINT mt:DEPLOYED.
      PRINT mt:HASDATA.
    }
  }
  RETURN "".
}

// events are preferred because there are no restrictions
FUNCTION partsDoScience {
  PARAMETER module.             // module target
  PARAMETER experiment.         // experiment name
  PARAMETER qtde.               // how many modules
  PARAMETER stats IS "".        // modules with status
  PARAMETER tag IS "".          // only parts with tag

  SET experiment TO "\b"+experiment+"\b".  // match any word
  LOCAL success IS false.
  LOCAL maxStage IS -1.
  IF tag = "" AND (defined stagingMaxStage) SET maxStage TO stagingMaxStage-1. //see lib_staging

  // list of modules
  SET moduleList TO List().
  FOR mT IN SHIP:MODULESNAMED(module) {
    // filter modules with status required
    IF NOT (stats = "") {
      IF mT:GETFIELD("status") = stats { moduleList:ADD(mT). }
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
          IF e:MATCHESPATTERN(experiment) {
            m:DOEVENT(e).
            WAIT UNTIL M:HASDATA.
            m:RESET.
            SET success TO true.
            SET qtde TO qtde-1.
          }
        }
      }
    }
  }
  RETURN success.
}

// Deploy science
FUNCTION partsScience {
  PARAMETER experiment.        // experiment Name.
  PARAMETER tag IS "".

  SET qtde TO 1.
  SET stats TO "".
  RETURN partsDoScience("ModuleScienceExperiment", experiment, qtde, stats, tag).
}