// Vessel has module searched
FUNCTION vesselHasModule {
  PARAMETER module.
  SET moduleList TO SHIP:MODULESNAMED(module).
  IF moduleList:LENGTH > 0 RETURN TRUE.
  RETURN FALSE.
}

FUNCTION vesselLightSensor {
  RETURN SHIP:SENSORS:LIGHT.
}