@lazyglobal off.

parameter TargetToFollow.
parameter DistanceToFollow is 30.
parameter speedlimit is 12.
parameter turnfactor is 3. // Turnfactor
parameter BreakTime is 10. // Time the craft need to stop with brakes.

runoncepath("lib/lib_autostart").
runoncepath("lib/lib_ui").
runoncepath("lib/lib_parts").
runoncepath("lib/lib_terrain").
runoncepath("lib/lib_rover").
runoncepath("lib/lib_warp").

local Waypoints is queue().

declare function saveWaypoints {
	writejson(Waypoints, "1:rover_wpt.json").
}
declare function loadWaypoints {
	if exists("1:rover_wpt.json") set Waypoints to readjson("1:rover_wpt.json").
	else set Waypoints to queue().
}
declare function WaypointsPeek {
	local wp is Waypoints:peek().
	return latlng(wp["lat"], wp["lng"]).
}
declare function WaypointsPop {
	local result is WaypointsPeek().
	if result:distance < 500 Waypoints:pop().
	return result.
}

local wtVAL is 0. //Wheel Throttle Value
local kTurn is 0. //Wheel turn value.
local targetspeed is 0. 
local targetdistance is 0.
local targetBearing is 0. 
local runmode is 0.
local RelSpeed is ship:groundspeed.
local FollowingVessel is false.
local gs is 0.
local NotifyInterval is 10.
local LastNotify is 0.
local NextWaypoint is 0.
local N is TerrainNormalVector().
local turnlimit is 0.

///////////////
// Main program
///////////////

//Deal with targets
if TargetToFollow:istype("lexicon") {
	set l to TargetToFollow.
	loadWaypoints().
	set speedlimit to l["speedlimit"].
	set distancetofollow to l["distancetofollow"].
	set turnfactor to l["turnfactor"].
	set breaktime to l["breaktime"].
	set NextWaypoint to ship:geoposition.
	Lock CoordToFollow to NextWaypoint.
}
else if TargetToFollow:istype("vessel") { 
	// Following another rover
	FollowingVessel on.
	lock CoordToFollow to TargetToFollow:geoposition.
}
else if TargetToFollow:istype("GeoCoordinates") {
	// Going to one point
	FollowingVessel off.
	lock CoordToFollow to TargetToFollow.
}
else if TargetToFollow:istype("List") {
	print("Setting up autostart").
	// Following a list of waypoints
	for Item in TargetToFollow {
		if Item:istype("GeoCoordinates") {
			 Waypoints:Push(lexicon("lat",Item:lat,"lng",Item:lng)).
		}
	}
	saveWaypoints().

	local l is lexicon().
	l:add("distancetofollow", distanceToFollow).
	l:add("speedlimit", speedlimit).
	l:add("turnfactor", turnfactor).
	l:add("breaktime", breaktime).
	autostartRoverAutosteer(l).

	set NextWaypoint to ship:geoposition.
	Lock CoordToFollow to NextWaypoint.
}

// Reset controls
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
brakes off.
sas off.
rcs off.
lights on.
fuelcells on.
partsDisableReactionWheels().
partsExtendAntennas().

// Check if rover is in a good state to be controlled.
if ship:status = "PRELAUNCH" {
	uiWarning("Rover","Rover is in Pre-Launch State. Launch it!").
	wait until ship:status <> "PRELAUNCH".
} else if ship:status <> "LANDED" {  
	uiError("Rover","Can't drive a rover that is " + ship:status).
	set runmode to -1.
}

local WThrottlePID is PIDLOOP(0.15,0.005,0.020, -1, 1). // Kp, Ki, Kd, MinOutput, MaxOutput
set WThrottlePID:SETPOINT TO 0. 

local SpeedPID is PIDLOOP(0.3,0.001,0.010,-speedlimit,speedlimit).
set SpeedPID:SETPOINT to 0.

local WSteeringkP is 0.010.
local WSteeringPID is PIDLOOP(WSteeringkP,0.0001,0.002, -1, 1). // Kp, Ki, Kd, MinOutput, MaxOutput
set WSteeringPID:SETPOINT TO 0. 

local powersave is false.
local lock ecPercent to partsPercentEC().

local Stop is False.
ON AG10 {
	uiBanner("Rover","Stopping.").
	SET Stop to True.
}

local save is false.
local savets is time:seconds.
local warping is false.

until runmode = -1 {
	set targetBearing to CoordToFollow:bearing.
	set TargetDistance to CoordToFollow:distance.
	set gs to vdot(ship:facing:vector,ship:velocity:surface).
	set turnlimit to min(1, turnfactor / abs(gs)). //Scale the turning radius based on current speed

	if savets + 600 < time:seconds {
		if not save print("Saving...").
		set save to true.
	}

	set N to TerrainNormalVector().
 
	if not powersave and ecPercent < 8 {
		set powersave to true.
		uiBanner("Rover","Low battery, power down",2).
		set warping to false.
	} else if powersave and ecPercent > 95 {
		set powersave to false.
		uiBanner("Rover","Battery charged, resuming",2).
		set warping to false.
	}

	// emergency shutdown
	if ecPercent < 1 brakes on.

	if RelSpeed < 0.01 and save {
		partsExtendSolarPanels("stop").
		partsExtendSolarPanels("landed").
		partsExtendAntennas("stop").
		partsExtendAntennas("landed").
		brakes on.
		wait 15.
		kuniverse:quicksaveto("rovering").
		set save to false.
		set warping to false.
		set savets to time:seconds.
	} else if RelSpeed < 0.1 {
		partsExtendSolarPanels("stop").
		partsExtendSolarPanels("landed").
		partsExtendAntennas("stop").
		partsExtendAntennas("landed").
		lights off.
	} else {
		partsRetractSolarPanels("stop").
		partsRetractSolarPanels("landed").
		partsRetractAntennas("stop").
		partsRetractAntennas("landed").
		lights on.
	}
	if Stop and RelSpeed < 0.1 set runmode to -1.

	if runmode = 0 { //Govern the rover 
		//Wheel Throttle and brakes:
		if powersave or Stop or save {
			if not warping {
				set warping to true.
				set warp to 0.
			}
			set targetspeed to 0.
			set brakes to RelSpeed < 2.
			set warping to false.
		} else {
			if not warping {
				set warping to true.
				physWarp(1).
			}
			if FollowingVessel or Waypoints:EMPTY() {
				// If following a vessel or have just one waypoint, use the distance from they to compute speed and braking.
				set targetspeed to SpeedPID:UPDATE(time:seconds,DistanceToFollow-TargetDistance).
				if RelSpeed > 2 set brakes to TargetDistance/RelSpeed <= BreakTime.
				else brakes off.
			} else {
				//When have a list of waypoints, use the distance to next waypoint plus cosine error to the next one to compute speed and braking.
				local SpeedFactor is WaypointsPeek():distance * max(0,cos(abs(WaypointsPeek():bearing))).
				set targetspeed to SpeedPID:UPDATE(time:seconds,DistanceToFollow-(TargetDistance+SpeedFactor)).
				if RelSpeed > 2 set brakes to (TargetDistance+SpeedFactor)/RelSpeed <= BreakTime.
				else brakes off.
			}
		}
		if FollowingVessel {			
			set RelSpeed to vdot(ship:facing:vector:normalized,(ship:velocity:surface-TargetToFollow:velocity:surface)).
		}
		else{
			set RelSpeed to gs.
		}
		set wtVAL to WThrottlePID:UPDATE(time:seconds,RelSpeed-targetspeed).
		

		//Steering:
		if gs < 0 set targetBearing to -targetBearing.
		set WSteeringPID:MaxOutput to  1 * turnlimit.
		set WSteeringPID:MinOutput to -1 * turnlimit.
		set WSteeringPID:kP to WSteeringkP * turnlimit*2.
		set kturn to WSteeringPID:UPDATE(time:seconds,targetBearing).

		//Detect jumps and engage stability control
		if ship:status <> "LANDED" {
			set warp to 0.
			if roverStabilzeJump(N) {
				uiBanner("Rover","Wow, that was a long jump!").
			}
		}
		//Detect rollover
		if roverIsRollingOver(ship, N) {
			set warp to 0.
			set turnfactor to max(1,turnfactor * 0.9). //Reduce turnfactor
			roverStabilzeJump(N). //Engage Stability control
		}
	}
	//Here it really control the rover.
	set wtVAL to min(1,(max(-1,wtVAL))).
	set kTurn to min(1,(max(-1,kTurn))).
	set SHIP:CONTROL:WHEELTHROTTLE to WTVAL.
	set SHIP:CONTROL:WHEELSTEER to kTurn.

	if not FollowingVessel {
		if abs(DistanceToFollow-TargetDistance) <= DistanceToFollow {
			if Waypoints:EMPTY() set runmode to -1.
			else {
				set NextWaypoint to WaypointsPOP().
				saveWaypoints().
				print("Next wp: " + round(NextWaypoint:distance) + "m, " + Waypoints:length + " to go").
			}
		}
	}
	wait 0. // Waits for next physics tick.
}

uiBanner("Rover","Automated driving stopped.",2).

//Clear before end
UNLOCK Throttle.
UNLOCK Steering.
partsEnableReactionWheels().
SET ship:control:translation to v(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
BRAKES ON.
LIGHTS OFF.

if Waypoints:length = 0 {
	print("Removing autostart data").
	autostartDelete().
	if exists("1:rover_wpt.json") deletepath("1:rover_wpt.json").
}

partsExtendSolarPanels("stop").
partsExtendSolarPanels("landed").
partsExtendAntennas("stop").
partsExtendAntennas("landed").
