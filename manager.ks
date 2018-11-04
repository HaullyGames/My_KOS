CLEARSCREEN.

ON AG10 REBOOT.

// load libraries
RUNONCEPATH("my/lib/lib_ui").
RUNONCEPATH("my/lib/lib_util").
RUNONCEPATH("my/lib/lib_parts").
RUNONCEPATH("my/lib/lib_science").
RUNONCEPATH("my/lib/lib_resources").


//countDown(3).

// Antennas 
//partsAntennas("retract", 0).
//WAIT 4.
//partsAntennas("extend", 0).

// Land Gears
//partsLandGears("retract").
//partsLandGears("extend").

// Fairing
//PRINT partsDeployFairings().

// Science
//partsScience("temperature").

// Valid existing module
//PRINT partsHasModule("ModuleReactionWheel").

SET count TO 0.
LOCAL stagingDecouplerModules IS LIST("ModuleDecouple", "ModuleAnchoredDecoupler","LaunchClamp").
LOCAL stagingTankFuels IS LIST("SolidFuel", "LiquidFuel").
LOCAL stagingTanks     IS LIST(). // list of tanks that all need to be empty to stage

LOCAL stages IS LIST().     //

//PRINT SHIP:PARTS:GETMODULE("ModuleDecouple").
SET T TO TIME:SECONDS.
PRINT partsInStage(stagingDecouplerModules).
PRINT (TIME:SECONDS - T).
//UNTIL count = STAGE:NUMBER {
//  stagingTanks:CLEAR().
//  PRINT "".
//  PRINT "Stage: " + (count).
//  SET listTemp TO partsInStage(count - 1).
//  //FOR p IN listTemp {
//  //  LOCAL amount IS 0.
//  //  PRINT resourcesIncludingChildren(p).
//  //  //FOR r IN p:RESOURCES {
//  //  //  IF stagingTankFuels:CONTAINS(r:NAME) {
//  //  //    SET amount TO amount + r:AMOUNT.
//  //  //  }
//  //  //}
//  //  //IF amount > 0.01 {
//  //  //  stagingTanks:ADD(p).
//  //  //}
//  //}
//  
//  //PRINT stagingTanks.
//  
//  SET count TO count + 1.
//}



//SET lightValue TO lightSensor().
//SET lightTries TO 10.
//SET timeCounter TO 0.
//// If has SolarPanel, try to get the max
//UNTIL 0 {
//  IF lightSensor() < 1.5 AND lightTries > 0 {
//    PRINT "FIND LIGHT!".
//    SET lightTries TO lightTries-1.
//    SET lightValue TO lightSensor().
//  }
//  ELSE IF lightTries = 0 {
//    CLEARSCREEN.
//    PRINT "Waitting!".
//    lock steering to heading(1,0).
//    IF timeCounter < 30 {
//      SET timeCounter TO timeCounter+1.
//    } ELSE {
//      UNLOCK steering.
//      SET timeCounter TO 0.
//      SET lightTries TO 10.
//    }
//  }
//  ELSE {
//    CLEARSCREEN.
//    SET lightTries TO 10.
//    PRINT "LIGHT OK!".
//    PRINT lightSensor().
//  }
//  wait 1/3.
//}

// Landing
//GLOBAL land_slip    IS 0.05. // transverse speed @ touchdown (m/s)
//global land_descend IS 10.0. // max speed during final descent (m/s)
//
//IF STATUS = "SUB_ORBITAL" OR STATUS = "FLYING" {
//  LOCK STEERING  TO LOOKDIRUP(-SHIP:VELOCITY:SURFACE, v(1,0,0)).
//  LOCAL grav     IS BODY:MU/(BODY:POSITION:MAG ^ 2).
//  LOCAL brake     IS FALSE.
//  LOCAL final     IS FALSE.
//  LOCAL touchdown IS FALSE.
//
//  UNTIL STATUS <> "SUB_ORBITAL" AND STATUS <> "FLYING" {
//    LOCAL accel     IS utilAssertAccel().
//    LOCAL geo      IS SHIP:GEOPOSITION.
//    LOCAL ground   IS GEO:POSITION:NORMALIZED.
//    LOCAL sv       IS SHIP:VELOCITY:SURFACE.
//    LOCAL svR      IS VDOT(sv, ground) * ground.
//    LOCAL svT      IS sv - svR.
//    LOCAL dtBrake  IS ABS(sv:MAG / accel).
//    LOCAL dtGround IS (SQRT(4 * grav * ABS(geo:POSITION:MAG) + sv:MAG^2) - sv:MAG) / (2 * grav).
//
//    IF final {
//      // Final descent: fall straight down; fire retros at touchdown.
//
//      // decide when to touch down
//      IF dtBrake >= dtGround - 1 {
//        SET touchdown TO TRUE.
//      }
//      // control transverse speed; keep it below allowable slip
//      IF svT:MAG > land_slip {
//        LOCAL SENSE IS SHIP:FACING.
//        LOCAL dirV IS V(
//          VDOT(svT, SENSE:STARVECTOR),
//          0,
//          VDOT(svT, SENSE:VECTOR)
//        ).
//        SET SHIP:CONTROL:TRANSLATION TO -(dirV / land_slip / 2).
//      }
//      ELSE {
//        SET SHIP:CONTROL:TRANSLATION TO 0.
//      }
//      // deploy legs and fire retros for soft touchdown
//      IF touchdown AND VDOT(svR, ground) > 0 {
//        LEGS ON.
//        LOCK THROTTLE TO (sv:Y / accel).
//      }
//      ELSE {
//        LOCK THROTTLE TO 0.
//      }
//    }
//    ELSE IF brake {
//      // Braking burn: scrub velocity down to final-descent speed
//      IF sv:MAG > land_descend {
//        CLEARSCREEN.
//        PRINT land_descend.
//        PRINT sv:MAG.
//        PRINT accel.
//        LOCK THROTTLE TO MIN((sv:MAG + land_descend)/accel, 1.0).
//      }
//      ELSE {
//        uiBanner("Landing", "Final descent").
//        LOCK STEERING TO LOOKDIRUP(-SHIP:GEOPOSITION:POSITION:NORMALIZED, V(1, 0, 0)).
//        RCS ON.
//        LOCK THROTTLE TO 0.
//        SET final TO TRUE.
//      }
//    }
//    ELSE {
//      // Deorbit: monitor & predict when to perform braking burn
//      LOCAL rF   IS POSITIONAT(SHIP, TIME:SECONDS + dtBrake).
//      LOCAL geoF IS BODY:GEOPOSITIONOF(rF).
//      LOCAL altF IS rf:Y - geoF:POSITION:Y.
//
//      CLEARSCREEN.
//      PRINT rf:Y.
//      PRINT geoF:POSITION:Y.
//      PRINT altF.
//      
//      IF altF > 0 {
//        uiBanner("Landing", "Braking burn").
//        SET brake TO TRUE.
//      }
//    }
//  }
//}
//