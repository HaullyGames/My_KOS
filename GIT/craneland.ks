runoncepath("lib/lib_ui.ks").
runoncepath("lib/lib_parts.ks").
runoncepath("lib/lib_staging.ks").

unlock all.
rcs on.
sas off.
lock steering to srfretrograde.
partsDoEvent("ModuleEnginesFX", "activate engine").
local bail is false.

local pid is pidloop(0.1, 0.016, 0.016).
set pid:setpoint to -15.
when alt:radar < 40 then set pid:setpoint to -2.
when alt:radar < 18 then set bail to true.

wait until alt:radar < 130.
partsCutChutes().

local thr is 0.3.
lock throttle to thr.

until bail {
  stagingCheck().
  set thr to min(1, thr + pid:update(time:seconds, ship:verticalspeed)).
  wait 0.
}

print("Bailing").
lock steering to up.
partsDetachWinches().
lock throttle to 1.
wait 3.
lock steering to prograde.
wait 3.
lock throttle to 0.
wait 1.
