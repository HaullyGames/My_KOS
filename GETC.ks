CLEARSCREEN.

PARAMETER Apo        IS 0.    // Target Apoapsis
PARAMETER hdglaunch  IS -90.   // Heading during launch (90 for equatorial prograde orbit)
PARAMETER launchRoll IS 0.     // What is the current Roll?
PARAMETER addWarp    IS FALSE. // Do warp automatic?
PARAMETER spinning   IS FALSE. // Launch spinning?

// Local Variables
// Validation before launch
LOCAL readyToLaunch IS FALSE.
LOCAL checked       IS FALSE.
LOCAL abortLaunch   IS FALSE.
LOCAL Fails IS LIST().
LOCAL counting     IS FALSE.
// Starting/Ending height of gravity turn
LOCAL launch_gt0 IS BODY:ATM:HEIGHT * 0.007.
LOCAL launch_gt1 IS MAX(BODY:ATM:HEIGHT * 0.7, BODY:RADIUS * 0.02).
// Handle MaxQ
LOCAL maxQ IS 0.3.
LOCAL pidMaxQ IS PIDLOOP(0.05).
LOCAL controlQ IS FALSE.
// Throttle.
LOCAL thr IS 1.
// Warpping?
LOCAL warped TO FALSE.

ON AG10 REBOOT.

// load libraries
RUNONCEPATH("my/lib/lib_ui").
RUNONCEPATH("my/lib/lib_util").
RUNONCEPATH("my/lib/lib_staging").
RUNONCEPATH("my/lib/lib_parts").
RUNONCEPATH("my/lib/lib_resources").

SET logconsole    TO TRUE. // Log outputs?
SET showInConsole TO FALSE. // Show ui output in console

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

  RETURN HEADING(0, pitch) * R(0,0,launchRoll).
}

// Throttle function for continuous lock.
LOCAL FUNCTION ascentThrottle {
  // reaching apoapsis
  LOCAL ApoPercent IS SHIP:OBT:APOAPSIS / Apo.
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

LOCAL FUNCTION validLaunchConditions {
  SET checked TO FALSE.
  Fails:CLEAR().
  LOCAL i IS Fails:LENGTH.

  IF SAS {
    Fails:ADD(LIST()).
    Fails[i]:ADD("SAS still ON, ignore?").
    Fails[i]:ADD(LEXICON("Y","Yes","N","No")).
    SET i TO i + 1.
  }
  IF BAYS {
    Fails:ADD(LIST()).
    Fails[i]:ADD("BAYS still open, ignore?").
    Fails[i]:ADD(LEXICON("Y","Yes","N","No")).
    SET i TO i + 1.
  }
  IF PANELS {
    Fails:ADD(LIST()).
    Fails[i]:ADD("PANELS still deployed, ignore?").
    Fails[i]:ADD(LEXICON("Y","Yes","N","No")).
    SET i TO i + 1.
  }
  IF RADIATORS {
    Fails:ADD(LIST()).
    Fails[i]:ADD("RADIATORS still deployed, ignore?").
    Fails[i]:ADD(LEXICON("Y","Yes","N","No")).
    SET i TO i + 1.
  }
  SET checked TO TRUE.
}

LOCAL FUNCTION takeDecision {
  WHEN checked AND NOT counting THEN {
    WHEN Fails:LENGTH > 0 THEN {
      LOCAL Question IS "".
      LOCAL Options IS LEXICON().
      IF Fails:LENGTH > 1 {
        SET Question TO "Check error list / Abort / Ignore All?".
        SET Options TO LEXICON("Y","Yes","N","Abort","A","Ignore ALL").
      }
      ELSE {
        SET Question TO "Check error list / Abort?".
        SET Options TO LEXICON("Y","Yes","N","Abort").
      }
      SET answer TO uiTerminalMenu(Question, Options , 3).
      IF answer = "Y" {
        SET F TO uiTerminalList("Something is wrong, continue?", Fails, 0).
        FOR Ops IN F:KEYS {
          IF F[Ops] = "Y" Fails:REMOVE(Ops).
          ELSE validLaunchConditions().
        }
      }
      ELSE IF  answer = "A" {
        Fails:CLEAR().
      }
      ELSE IF answer = "N" {
        CLEARSCREEN.
        SET abortLaunch TO TRUE.
      }
    }
    IF Fails:LENGTH = 0 {
      CLEARSCREEN.
      SET checked TO FALSE.     // Stop run this loop.
      SET readyToLaunch TO TRUE.
    }
    PRESERVE.
  }
}

// CountDown without stop program
LOCAL FUNCTION countDown {
  PARAMETER T IS 10.
  // Local variables
  LOCAL timeToUpdate IS TIME:SECONDS + 1.
  LOCAL count        IS 0.

  SET counting TO TRUE.
  uiBanner("CountDown", "Countdown initiated:").

  WHEN TIME:SECONDS > timeToUpdate AND counting THEN {
    uiBanner("CountDown", "T -" + T, 1).
    SET timeToUpdate TO TIME:SECONDS + 1.
    IF T = 0 { 
      SET counting TO FALSE.
    }
    SET T TO T - 1.
    PRESERVE.
  }
}

// Perform initial setup; trim ship for ascent.
IF Apo = 0 SET Apo TO utilMinimumApo().
IF launchRoll = 0 SET launchRoll TO defaultRotation().
SET pidMaxQ:SETPOINT TO maxQ.

uiBanner("ascend", "Ascend to " + ROUND(Apo/1000) + "km; Heading " + hdglaunch + "º").
countDown(10).
SAS OFF.
BAYS OFF.
PANELS OFF.
IF PANELS partsSolarPanels("RETRACT").
RADIATORS OFF.
partsAntennas("RETRACT").
validLaunchConditions().
takeDecision().

UNTIL readyToLaunch OR abortLaunch {
  WAIT 0.1.
  IF abortLaunch {
    uiError("Launch: ", "Launch Aborted!").
  }
  ELSE IF readyToLaunch {
    LOCK STEERING TO ascentSteering().
    LOCK THROTTLE TO ascentThrottle().

    // Enter ascent loop.
    UNTIL SHIP:OBT:APOAPSIS >= Apo OR (SHIP:ALTITUDE > Apo/2 AND ETA:APOAPSIS < 30) {
      stagingCheck().
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
    LOCK STEERING TO HEADING(hdglaunch * (-1),0). //Horizon, ceiling up.
    WAIT UNTIL utilIsShipFacing(HEADING(hdglaunch * (-1),0):VECTOR).

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
  }
}.