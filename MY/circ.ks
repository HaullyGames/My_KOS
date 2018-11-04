////////////////////////////////////////////////////////
// Circularize.                                       //
////////////////////////////////////////////////////////
// Circularizes at the nearest apoapsis or periapsis  //
////////////////////////////////////////////////////////
PARAMETER addWarp IS FALSE.    // Do warp in Circularize?

ON AG10 REBOOT.
// load libraries
RUNONCEPATH("lib/lib_ui").
RUNONCEPATH("lib/lib_util").

IF CAREER():CANMAKENODES AND PERIAPSIS > MAX(BODY:ATM:HEIGHT, 100) {
  utilRemoveNodes().
  IF (OBT:TRANSITION = "ESCAPE" OR ETA:PERIAPSIS < ETA:APOAPSIS) {
    RUN NODE({RUN node_apo(OBT:PERIAPSIS).}).
  }
  ELSE { 
    RUN NODE({RUN node_peri(OBT:APOAPSIS).}).
  }
}
ELSE IF APOAPSIS > 0 AND ETA:APOAPSIS < ETA:PERIAPSIS {
  RUNONCEPATH("lib/lib_staging").
  RUNONCEPATH("lib/lib_vessel").
  RUNONCEPATH("lib/lib_warp").

  // Local Function
  LOCAL FUNCTION circSteering {
    IF ETA:APOAPSIS < ETA:PERIAPSIS {
      // prevent raising apoapsis
      IF ETA:APOAPSIS > 1 RETURN VELOCITYAT(SHIP,TIME:SECONDS+ETA:APOAPSIS):ORBIT.
      //go prograde in last second (above velocityAt often has problems with time=now)
      RETURN PROGRADE.
    }
    // pitch up a bit when we passed apopapsis to compensate for potentionally low TWR as this is often used after launch script
    // note that ship's pitch is actually yaw in world perspective (pitch = normal, yaw = radial-out)
    RETURN PROGRADE:VECTOR+R(0,MIN(30,MAX(0,ORBIT:PERIOD-ETA:APOAPSIS)),0).
  }

  // Local variables
  LOCAL maxHeight IS 0.
  LOCAL sstate IS SAS.
  SET v0 TO VELOCITYAT(SHIP,TIME:SECONDS+ETA:APOAPSIS):ORBIT.

  SAS OFF.
  LOCK STEERING TO v0.

  stagingPrepare().
  // deltaV = required orbital speed minus predicted speed
  SET dv TO SQRT(BODY:MU/(BODY:RADIUS+APOAPSIS))-v0:MAG.
  SET dt TO burnTimeForDv(dv)/2.

  IF vesselHasModule("ModuleReactionWheel") WAIT UNTIL utilIsShipFacing(v0) OR ETA:APOAPSIS < dt - 30.
  IF addWarp warpSeconds(ETA:APOAPSIS - dt - 30).
  LOCK STEERING TO PROGRADE.
  WAIT UNTIL utilIsShipFacing(PROGRADE:FOREVECTOR).
  IF addWarp warpSeconds(ETA:APOAPSIS - dt - 5).
  ELSE {
    PRINT (ETA:APOAPSIS - dt - 5).
    WAIT UNTIL (ETA:APOAPSIS - dt - 5).
  }
  SET maxHeight TO SHIP:OBT:APOAPSIS * 1.01 + 1000.

  LOCK STEERING TO circSteering().
  LOCK THROTTLE TO (SQRT(BODY:MU/(BODY:RADIUS+APOAPSIS))-SHIP:VELOCITY:ORBIT:MAG)*SHIP:MASS/MAX(1,AVAILABLETHRUST).

  UNTIL ORBIT:ECCENTRICITY < 0.000005                                               // circular
    OR (ETA:APOAPSIS > ORBIT:PERIOD/3 AND ETA:APOAPSIS < ORBIT:PERIOD*2/3)          // happens with good accuracy
    OR (ORBIT:APOAPSIS > maxHeight AND PERIAPSIS > MAX(BODY:ATM:HEIGHT,1000)+100)    // something went wrong?
    OR (ORBIT:APOAPSIS > maxHeight*1.5+5000)                                         // something went really really wrong
  {
    stagingCheck().
    wait 0.5.
  }
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
  UNLOCK ALL.
  SET SAS TO sstate.
  IF ORBIT:ECCENTRICITY > 0.1 OR ORBIT:PERIAPSIS < MAX(BODY:ATM:HEIGHT,100)
    uiFatal("Circ", "Error; e=" + ROUND(ORBIT:ECCENTRICITY, 3) + ", peri=" + ROUND(PERIAPSIS)).
}
ELSE
  uiError("Circ", "Either escape trajectory or closer to periapsis").//TODO
