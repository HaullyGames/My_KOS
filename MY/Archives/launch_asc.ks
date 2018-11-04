//////////////////////////////////////////////////////////////////////////////
// Ascent phase of launch.                                                  //
//////////////////////////////////////////////////////////////////////////////
// Ascend from a planet, performing a gravity turn and staging as necessary.//
// Achieve circular orbit with desired apoapsis.                            //
//////////////////////////////////////////////////////////////////////////////

PARAMETER Apo IS 0.           // Apoapsis
PARAMETER hdglaunch IS -90.   // Heading during launch (90 for equatorial prograde orbit)
PARAMETER addWarp IS FALSE.   // Do warp in Launch?
PARAMETER launchRoll IS 0.

// Local Variables
// Starting/Ending height of gravity turn
LOCAL launch_gt0 IS BODY:ATM:HEIGHT * 0.007.
LOCAL launch_gt1 IS MAX(BODY:ATM:HEIGHT * 0.7, BODY:RADIUS * 0.02).
// Throttle.
LOCAL maxQ IS 0.3.
LOCAL pidMaxQ IS PIDLOOP(0.05).
LOCAL thr IS 1.
LOCAL controlQ IS FALSE.
// Parts were deployed in altitude
LOCAL deployed IS FALSE.
// Doing warpping?
LOCAL warped TO FALSE.

ON AG10 REBOOT.
// load libraries
runoncepath("lib/lib_parts").
runoncepath("lib/lib_ui").
runoncepath("lib/lib_util").
runoncepath("lib/lib_warp").
runoncepath("lib/lib_staging").

// Final apoapsis (m altitude)
LOCAL FUNCTION defaultApo {
  IF BODY:ATM:EXISTS RETURN BODY:ATM:HEIGHT + 10000.
  RETURN MIN(15000, BODY:RADIUS * 0.08).
}

// Roll/rotation during launch.
LOCAL FUNCTION defaultRotation {
  IF(SHIP:ALTITUDE < 200) RETURN SHIP:FACING:ROLL.
  // do not rotate the rocket 180° if we are already facing the proper way
  IF ABS(SHIP:FACING:ROLL-180-hdglaunch) < 30 RETURN 0.
  RETURN 180. // needed for shuttles, should not harm rockets
}

// Steering function for continuous lock.
LOCAL FUNCTION ascentSteering {
//  How far through our gravity turn are we? (0..1)
  LOCAL gtPct IS MIN(1,MAX(0, (SHIP:ALTITUDE - launch_gt0) / (launch_gt1 - launch_gt0))).
//  Ideal gravity-turn azimuth (inclination) and facing at present altitude.
  SET gtPct TO gtPct * (-1).
  LOCAL pitch IS ARCCOS(gtPct).

  RETURN HEADING(hdglaunch, pitch) * R(0,0,launchRoll).
}

// Throttle function for continuous lock.
LOCAL FUNCTION ascentThrottle {
  // reaching apoapsis
  LOCAL ApoPercent IS SHIP:OBT:APOAPSIS/Apo.
  IF ApoPercent > 0.95 {
    LOCAL ApoCompensation IS (ApoPercent - 0.95) * 10.
    SET thr TO 1.05 - MIN(1, MAX(0, ApoCompensation)).
    RETURN thr.
  }

  SET controlQ TO (SHIP:Q > maxQ * 0.8 AND NOT (SHIP:Q < 0.2)).
  IF controlQ {
    SET thr TO thr + pidMaxQ:UPDATE(TIME:SECONDS, SHIP:Q).
    SET thr TO MAX(0.1, MIN(thr, 1)).
    RETURN thr.
  }

  SET thr TO 1.
  RETURN thr.
}

// Deploy fairings and panels at proper altitude; call in a loop.
LOCAL FUNCTION ascentDeploy {
  IF deployed RETURN.
  IF SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT RETURN.
  SET deployed TO TRUE.

  IF partsDeployFairings() {
    WAIT 0.
  }
  PANELS ON.
  partsAntennas("extend").
}

IF Apo = 0 SET Apo TO defaultApo().
IF launchRoll = 0 SET launchRoll TO defaultRotation().

uiBanner("ascend", "Ascend to " + ROUND(Apo/1000) + "km; Heading " + hdglaunch + "º").

SET pidMaxQ:SETPOINT TO maxQ.

// Perform initial setup; trim ship for ascent.
SAS OFF.
BAYS OFF.
PANELS OFF.
WAIT 3.
// IF still have some panel deployed, try retract it.
// Some panels can't be retracted once deployed.
IF PANELS partsSolarPanels("retract").
RADIATORS OFF.
partsAntennas("retract").

// Start CountDown to Launch
countDown().

LOCK STEERING TO ascentSteering().
LOCK THROTTLE TO ascentThrottle().

// Enter ascent loop.
UNTIL SHIP:OBT:APOAPSIS >= Apo OR (SHIP:ALTITUDE > Apo/2 AND ETA:APOAPSIS < 30) {
  stagingCheck().
  ascentDeploy().
  // Retract land gears
  IF NOT (SHIP:STATUS = "LANDED" AND landGearRetracted) {
    LEGS OFF.
  }

  IF addWarp {
    IF NOT warped AND altitude > MIN(SHIP:BODY:ATM:HEIGHT/10,1000) {
      SET warped TO TRUE.
      physWarp(1).
    }
  }
  WAIT 0.
}

UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

// Coast to apoapsis and hand off to circularization program.
// Roll with top up
LOCK STEERING TO HEADING(hdglaunch*(-1),0). //Horizon, ceiling up.
WAIT UNTIL utilIsShipFacing(HEADING(hdglaunch*(-1),0):VECTOR).

// Warp to end of atmosphere
LOCAL AdjustmentThrottle IS 0.
LOCK THROTTLE TO AdjustmentThrottle.
UNTIL SHIP:ALTITUDE > BODY:ATM:HEIGHT {
  stagingCheck().
  ascentDeploy().
  IF SHIP:OBT:APOAPSIS < Apo {
    SET AdjustmentThrottle TO ascentThrottle().
    WAIT 0.
  } 
  ELSE {
    SET AdjustmentThrottle TO 0.
    WAIT 0.5.
  }
}
IF warped resetWarp().

// Circularize
UNLOCK ALL.
RUN circ(addWarp).