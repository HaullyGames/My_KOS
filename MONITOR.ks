FUNCTION deltaVstage
{
  // info for and from stageDeltaV
  LOCAL isp_g0 IS BODY:MU/BODY:RADIUS^2. // exactly 9.81 in ksp 1.3.1, 9.80665 for Earth
  LOCAL stageAvgIsp    IS 0.             // average isp in seconds
  LOCAL stageBurnTime  IS 0.             // updated in stageDeltaV()
  LOCAL stageDryMass   IS 0.             // dry mass just before staging
  
  // fuel name list
  LOCAL stagingConsumed IS LIST("SolidFuel", "LiquidFuel", "Oxidizer", "MonoPropellant").
  
  // prepare dry mass for stageDeltaV()
  LOCAL fuelMass IS 0.
  FOR r IN STAGE:RESOURCES {
    IF stagingConsumed:CONTAINS(r:NAME) {
      SET fuelMass TO fuelMass + r:AMOUNT * r:DENSITY.
      PRINT "Resource: "+ r:NAME + ", Amount: " + r:AMOUNT.
    }
  }

  
  SET stageDryMass TO SHIP:MASS - fuelMass.

  // thrust weighted average isp
  LOCAL thrustTotal IS 0.
  LOCAL mDotTotal IS 0.
  
  // prepare list of engines that are to be decoupled by staging
  // and average isp for stageDeltaV()
  LIST ENGINES IN engList.
  LOCAL thrust IS 0.
  LOCAL flow IS 0.
  FOR e IN engList {
    IF e:IGNITION {
      LOCAL t IS e:MAXTHRUST * e:THRUSTLIMIT/100. // if multi-engine with different thrust limiters
      IF e:ISP > 0 {
        SET thrust TO thrust + t.
        SET flow TO flow + t / e:ISP. // thrust = isp * g0 * dm/dt => flow = sum of thrust/isp
        PRINT "Engine: "+ e:NAME + ", Thrust: " + t.
      }
    }
  }

  IF flow > 0 {
    SET stageAvgIsp TO THRUST / flow.
  }
  
  IF AVAILABLETHRUST > 0 {
  SET stageBurnTime TO (stageAvgIsp * isp_g0) * (SHIP:MASS - stageDryMass)/AVAILABLETHRUST.
  }

  LOCAL deltaV IS stageAvgIsp * isp_g0 * LN(SHIP:MASS/(SHIP:MASS - fuelMass)).

  PRINT "DeltaV: " + deltaV.
  PRINT "BurnTime:" + stageBurnTime.
}.

UNTIL 0 > 0 {
  deltaVstage.
  WAIT 0.1.
  CLEARSCREEN.
  }