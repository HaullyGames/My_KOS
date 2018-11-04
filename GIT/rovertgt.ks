@lazyglobal off.

Parameter MaxSpeed is 12.
Parameter WaypointTolerance is 50.

runoncepath("lib/lib_ui").

local WP is list().
global settings is lexicon().
settings:add("IPU", 2000).
settings:add("MinSlope", -15).
settings:add("MaxSlope", 20).

for w in allwaypoints(){
    if w:body = ship:body {
        WP:Add(w).
    }
}.
local SelectedIndex is uiTerminalList(WP).

local route is list().
route:add(ship:geoposition).
route:add(WP[SelectedIndex]:geoposition).

run rover_autosteer(route,WaypointTolerance,MaxSpeed).
