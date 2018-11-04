// Library for staging logic and deltaV calculation
// ================================================
// Asparagus and designs that throw off empty tanks were considered.
// Note that engines attached to tanks that get empty will be staged
// (even if not technically flamed out - that is something that KER and MechJeb do not consider).

// logic: Stage if either availableThrust = 0 (separator-only, fairing-only stage)
// or all engines that are to be separated by staging flame out
// or all tanks (and boosters) to be separated that were not empty are empty now

// tag noauto: use "noauto" tag on any decoupler to instruct this library to never stage it
// note: can use multiple tags if separated by whitespace (e.g. "noauto otherTag") or other word-separators ("tag,noauto.anything;more").

// list of all consumed fuels (for deltaV; add e.g. Karbonite and/or MonoPropellant if using such mods)
IF NOT (DEFINED stagingConsumed)
GLOBAL stagingConsumed IS LIST("SolidFuel", "LiquidFuel", "Oxidizer").

// list of fuels for empty-tank identification (for dual-fuel tanks use only one of the fuels)
// note: SolidFuel is in list for booster+tank combo, both need to be empty to stage
IF NOT (DEFINED stagingTankFuels)
GLOBAL stagingTankFuels IS LIST("SolidFuel", "LiquidFuel"). //Oxidizer intentionally not included (would need extra logic)

// list of modules that identify decoupler
IF NOT (DEFINED stagingDecouplerModules)
GLOBAL stagingDecouplerModules IS LIST("ModuleDecouple", "ModuleAnchoredDecoupler","LaunchClamp").

// Standard gravity for isp
// https://en.wikipedia.org/wiki/Specific_impulse
// https://en.wikipedia.org/wiki/Standard_gravity
IF NOT (DEFINED isp_g0)
GLOBAL isp_g0 IS BODY:MU/BODY:RADIUS^2. // exactly 9.81 in ksp 1.3.1, 9.80665 for Earth
// note that constant:G*kerbin:mass/kerbin:radius^2 yields 9.80964723..., correct value could be 9.82

// work variables for staging logic
GLOBAL stagingNumber   IS -1.     // stage:number when last calling stagingPrepare()
GLOBAL stagingMaxStage IS 0.      // stop staging if stage:number is lower or same as this
GLOBAL stagingResetMax IS TRUE.   // reset stagingMaxStage to 0 if we passed it (search for next "noauto")
GLOBAL stagingEngines  IS LIST(). // list of engines that all need to flameout to stage
GLOBAL stagingTanks    IS LIST(). // list of tanks that all need to be empty to stage

// info for and from stageDeltaV
GLOBAL stageAvgIsp    IS 0.    // average isp in seconds
GLOBAL stageStdIsp    IS 0.    // average isp in N*s/kg (stageAvgIsp*isp_g0)
GLOBAL stageDryMass   IS 0.    // dry mass just before staging
GLOBAL stageBurnTime  IS 0.    // updated in stageDeltaV()

// return stage number where the part is decoupled (probably Part.separationIndex in ksp api)
FUNCTION stagingDecoupledIn {
  PARAMETER part.

  LOCAL FUNCTION partIsDecoupler {
    PARAMETER part.
    FOR m IN stagingDecouplerModules {
      IF part:MODULES:CONTAINS(m) {
        IF part:TAG:TOLOWER:MATCHESPATTERN("\bnoauto\b") AND part:STAGE+1 >= stagingMaxStage
          SET stagingMaxStage TO part:STAGE+1.
        RETURN TRUE.
      }
    }
    RETURN FALSE.
  }
  UNTIL partIsDecoupler(part) {
    IF NOT part:HASPARENT RETURN -1.
    SET part TO part:PARENT.
  }
  RETURN part:STAGE.
}

// to be called whenever current stage changes to prepare data for quicker test and other functions
FUNCTION stagingPrepare {
  WAIT UNTIL STAGE:READY.
  SET stagingNumber TO STAGE:NUMBER.
  IF stagingResetMax AND stagingMaxStage >= stagingNumber SET stagingMaxStage TO 0.
  stagingEngines:CLEAR().
  stagingTanks:CLEAR().

  // prepare list of tanks that are to be decoupled and have some fuel
  LIST parts IN PARTS.
  FOR p IN parts {
    LOCAL amount IS 0.
    FOR r IN p:RESOURCES {
      IF stagingTankFuels:CONTAINS(r:NAME) {
        SET amount TO amount + r:AMOUNT.
      }
    }
    IF amount > 0.01 AND stagingDecoupledIn(p) = STAGE:NUMBER-1 {
      stagingTanks:ADD(p).
    }
  }

  // prepare list of engines that are to be decoupled by staging
  // and average isp for stageDeltaV()
  LIST engines IN ENGINES.
  LOCAL thrust IS 0.
  LOCAL flow IS 0.
  FOR e IN engines {
    IF e:IGNITION AND e:ISP > 0 {
      IF stagingDecoupledIn(e) = STAGE:NUMBER-1 {
        stagingEngines:ADD(e).
      }

      LOCAL t IS e:AVAILABLETHRUST.
      SET thrust TO thrust + t.
      SET flow TO flow + t / e:ISP. // thrust=isp*g0*dm/dt => flow = sum of thrust/isp
    }
  }
  SET stageAvgIsp TO 0.
  IF flow > 0 {
    SET stageAvgIsp TO thrust/flow.
  }
  SET stageStdIsp TO stageAvgIsp * isp_g0.

  // prepare dry mass for stageDeltaV()
  LOCAL fuelMass IS 0.
  FOR r IN STAGE:RESOURCES {
    IF stagingConsumed:contains(r:name) {
      SET fuelMass TO fuelMass + r:amount*r:density.
    }
  }
  SET stageDryMass TO ship:mass-fuelMass.
}

// to be called repeatedly
FUNCTION stagingCheck {
  wait until stage:ready.
  IF STAGE:NUMBER <> stagingNumber {
    stagingPrepare().
  }
  IF STAGE:NUMBER <= stagingMaxStage {
    RETURN.
  }

  // need to stage because all engines are without fuel?
  LOCAL FUNCTION checkEngines {
    IF stagingEngines:empty {
      RETURN FALSE.
    }
    FOR e IN stagingEngines {
      IF NOT e:flameout {
        RETURN FALSE.
      }
    }
    RETURN TRUE.
  }

  // need to stage because all tanks are empty?
  LOCAL FUNCTION checkTanks {
    IF stagingTanks:empty {
      RETURN FALSE.
    }
    FOR t IN stagingTanks {
      LOCAL amount IS 0.
      FOR r IN t:resources {
        IF stagingTankFuels:CONTAINS(r:NAME) {
          SET amount TO amount + r:amount.
        }
      }
      IF amount > 0.01 RETURN FALSE.
    }
    RETURN TRUE.
  }

  // check staging conditions and return true if staged, false otherwise
  IF AVAILABLETHRUST = 0 OR checkEngines() OR checkTanks() {
    STAGE.
    // this is optional and unnecessary if twr does not change much,
    // but can prevent weird steering behaviour after staging
    STEERINGMANAGER:RESETPIDS().
    // prepare new data
    stagingPrepare().
    RETURN TRUE.
  }
  RETURN FALSE.
}

// delta-V remaining for current stage
// + stageBurnTime updated with burn time at full throttle
FUNCTION stageDeltaV {
  IF stageAvgIsp = 0 OR AVAILABLETHRUST = 0 {
    SET stageBurnTime TO 0.
    RETURN 0.
  }
  SET stageBurnTime TO stageStdIsp * (SHIP:MASS - stageDryMass)/AVAILABLETHRUST.
  RETURN stageStdIsp * LN(SHIP:MASS / stageDryMass).
}

// calculate burn time for maneuver needing provided deltaV
FUNCTION burnTimeForDv {
  PARAMETER dv.
  RETURN stageStdIsp * SHIP:MASS*(1-CONSTANT:E^(-dv / stageStdIsp))/AVAILABLETHRUST.
}

// current thrust to weght ratio
FUNCTION thrustToWeight {
  RETURN AVAILABLETHRUST/(SHIP:MASS*BODY:MU)*(BODY:RADIUS+ALTITUDE)^2.
}
