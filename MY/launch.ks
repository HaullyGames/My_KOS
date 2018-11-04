@LAZYGLOBAL OFF.

CLEARSCREEN.
/////////////////////////////////////////////////////
// Launch.ks just try to decide if is better to use//
// launch_asc.ks or launch_ssto.ks                 //
/////////////////////////////////////////////////////
PARAMETER Apo IS 0.
PARAMETER hdg IS 0.
PARAMETER addWarp IS FALSE.    // Do warp in Launch?

ON AG10 REBOOT.

IF KUniverse:ORIGINEDITOR = "SPH" OR SHIP:NAME:CONTAINS("SSTO") {
    RUNPATH("launch_ssto", Apo, hdg, addWarp).
} 
ELSE {
  RUNPATH("launch_asc", Apo, hdg, addWarp).
}
