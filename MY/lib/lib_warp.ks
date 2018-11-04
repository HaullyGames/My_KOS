FUNCTION resetWarp {
  KUNIVERSE:TIMEWARP:CANCELWARP().
  SET WARP TO 0.
  WAIT 0.
  WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
  SET WARPMODE TO "RAILS".
  WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
}

FUNCTION railsWarp {
  PARAMETER w.
  IF WARPMODE <> "RAILS" resetWarp().
  SET WARP TO w.
}

FUNCTION physWarp {
  PARAMETER w.
  IF WARPMODE <> "PHYSICS" {
    KUNIVERSE:TIMEWARP:CANCELWARP().
    WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
    SET WARPMODE TO "PHYSICS".
  }
  SET WARP TO w.
}

FUNCTION warpSeconds {
  PARAMETER seconds.
  IF seconds <= 1 RETURN 0.
  LOCAL t1 IS TIME:SECONDS+seconds.
  IF TIME:SECONDS < t1-1 {
    resetWarp().
    IF TIME:SECONDS < t1-10 {
      WARPTO(t1).
      WAIT 1.
      WAIT UNTIL TIME:SECONDS >= t1-1.
    } 
    ELSE {
      // warpTo will not warp 10 seconds and less
      IF TIME:SECONDS < t1-3 {
        physWarp(4).
        WAIT UNTIL TIME:SECONDS >= t1-3.
      }
      IF TIME:SECONDS < t1-2 {
        physWarp(3).
        WAIT UNTIL TIME:SECONDS >= t1-2.
      }
      IF TIME:SECONDS < t1-1 {
        physWarp(2).
        WAIT UNTIL TIME:SECONDS >= t1-1.
      }
    }
  }
  resetWarp().
  WAIT UNTIL TIME:SECONDS >= t1.
  resetWarp().
  WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
  RETURN seconds.
}
