// This library contains generic function
// List:
// - CountDown (case Wait) (utilCountDown).
// - Convert Methods:
//   - m/s To km/h         (utilMsToKmH)
// - Get min Apoapsis      (utilMinimumApo).


// GLOBAL Variables
// Initial SAS/RCS values before script
GLOBAL initialSAS IS SAS.
GLOBAL initialRCS IS RCS.

// CountDown
// This will makes who calls it wait.
FUNCTION utilCountDown {
  PARAMETER seconds IS 10.
  uiBanner("CountDown", "Countdown initiated:").
  FROM {LOCAL x IS seconds.} UNTIL x = 0 STEP {SET x TO x - 1.} DO {
    uiBanner("CountDown", "T -" + x, 1).
    WAIT 1.
  }
  RETURN.
}

// Convert m/s To km/h. 
FUNCTION utilMsToKmH { 
    PARAMETER MS.
    RETURN MS * 3.6.
}

// Returns true if:
// -  Ship is facing the FaceVec whiting a tolerance of maxDeviationDegrees and
//    with a Angular velocity less than maxAngularVelocity.
FUNCTION utilIsShipFacing { 
  PARAMETER face.
  PARAMETER maxDeviationDegrees IS 8.
  PARAMETER maxAngularVelocity IS 0.01.

  IF face:ISTYPE("DIRECTION") {
    SET face TO face:VECTOR.
  }
  RETURN VDOT(face:NORMALIZED, SHIP:FACING:FOREVECTOR:NORMALIZED) >= COS(maxDeviationDegrees) 
         AND SHIP:ANGULARVEL:MAG < maxAngularVelocity.
}

FUNCTION utilAssertAccel {
  LOCAL utiliAccel IS SHIP:AVAILABLETHRUST/SHIP:MASS. // kN over tonnes; 1000s cancel

  IF utiliAccel <= 0 {
    uiFatal("Maneuver", "ENGINE FAULT").
  } 
  ELSE {
    RETURN utiliAccel.
  }
}

// Get minimum Apoapsis for the body
//  - Input: Body target
//  - Output: Apoapsis
FUNCTION utilMinimumApo {
  PARAMETER b IS BODY.  // Body target? Current is the defaul.

  IF b:ATM:EXISTS {
    RETURN b:ATM:HEIGHT + 5000.
  }
  RETURN MIN(15000, b:RADIUS * 0.08).
}

// Continuous Rotation.
FUNCTION utilContRotation {
  PARAMETER currentR.

  RETURN 180.
}

// the math needed for suicide burn and final decent
FUNCTION decent_math {
  LOCAL localGrav IS SHIP:BODY:MU/(SHIP:BODY:RADIUS + SHIP:ALTITUDE)^2.   // calculates gravity of the body
  LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.             // ship acceleration in m/s
  LOCAL stopTime IS  ABS(VERTICALSPEED) / (shipAcceleration - localGrav).   // time needed to neutralize vertical speed
  LOCAL stopDist IS 1/2 * shipAcceleration * stopTime * stopTime.           // how much distance is needed to come to a stop
  LOCAL twr IS shipAcceleration / localGrav.                               // the TWR of the craft based on local gravity
  //RETURN LEX("stopTime",stopTime,"stopDist",stopDist,"twr",twr).
  RETURN twr.
}


//FUNCTION deltaVstage
//{
//  PARAMETER x.
//  // info for and from stageDeltaV
//  LOCAL isp_g0 IS BODY:MU/BODY:RADIUS^2. // exactly 9.81 in ksp 1.3.1, 9.80665 for Earth
//  LOCAL stageAvgIsp    IS 0.             // average isp in seconds
//  LOCAL stageBurnTime  IS 0.             // updated in stageDeltaV()
//  LOCAL stageDryMass   IS 0.             // dry mass just before staging
//  
//  // fuel name list
//  LOCAL stagingConsumed IS LIST("SolidFuel", "LiquidFuel", "Oxidizer", "MonoPropellant").
//  
//  // prepare dry mass for stageDeltaV()
//  LOCAL fuelMass IS 0.
//  FOR r IN STAGE:RESOURCES {
//    IF stagingConsumed:CONTAINS(r:NAME) {
//      SET fuelMass TO fuelMass + r:AMOUNT * r:DENSITY.
//      PRINT "Resource: " + R:NAME   AT (0,x).
//      PRINT "  Amount: " + R:AMOUNT AT (0,x+1).
//      SET X TO X + 2.
//    }
//  }
//
//  SET stageDryMass TO SHIP:MASS - fuelMass.
//
//  // thrust weighted average isp
//  LOCAL thrustTotal IS 0.
//  LOCAL mDotTotal IS 0.
//  
//  // prepare list of engines that are to be decoupled by staging
//  // and average isp for stageDeltaV()
//  LIST ENGINES IN engList.
//  LOCAL thrust IS 0.
//  LOCAL flow IS 0.
//  FOR e IN engList {
//    IF e:IGNITION {
//      LOCAL t IS e:MAXTHRUST * e:THRUSTLIMIT / 100. // if multi-engine with different thrust limiters
//      IF e:ISP > 0 {
//        SET thrust TO thrust + t.
//        SET flow TO flow + t / e:ISP. // thrust = isp * g0 * dm/dt => flow = sum of thrust/isp
//        PRINT "  Engine: "+ e:NAME + ", Thrust: " + t  AT (0,x).
//        SET X TO X + 1.
//      }
//    }
//    IF e:FLAMEOUT AND STAGE:NUMBER > 0 {
//      //STAGE.
//      //WAIT 0.5.
//      CLEARSCREEN.
//    }
//  }
//
//  IF(SHIP:ALTITUDE > 200) {
//    SET rotationT TO rotationT + 0.01.
//    IF rotationT > 1 SET rotationT TO 0.
//    LOCK STEERING TO ascentSteering().
//  }
//
//  IF flow > 0 {
//    SET stageAvgIsp TO THRUST / flow.
//  }
//  
//  IF AVAILABLETHRUST > 0 {
//  SET stageBurnTime TO (stageAvgIsp * isp_g0) * (SHIP:MASS - stageDryMass)/AVAILABLETHRUST.
//  }
//
//  LOCAL deltaV IS stageAvgIsp * isp_g0 * LN(SHIP:MASS/(SHIP:MASS - fuelMass)).
//
//  PRINT "  DeltaV: " + deltaV AT(0,x).
//  PRINT "BurnTime: " + stageBurnTime AT(0,x+1).
//}

//LOCAL refreshSec IS 0.2.
//SET timeToUpdate TO TIME:SECONDS + refreshSec.

// fuel name list
//LOCAL stagingConsumed IS LIST("SolidFuel", "LiquidFuel", "Oxidizer", "MonoPropellant").

//WHEN TIME:SECONDS > timeToUpdate THEN {
//
//  SET x TO 2.
//
//  PRINT "Stage: " + STAGE:NUMBER AT (0,0).
//  
//  // prepare dry mass for stageDeltaV()
//  // deltaVstage(x).
// // PRINT "Other Code".
//        
//  SET timeToUpdate to TIME:SECONDS + refreshSec.
//  PRESERVE.
//}