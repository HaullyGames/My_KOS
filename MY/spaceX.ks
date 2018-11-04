clearscreen.

SET ag8        TO FALSE.
SET ag9        TO FALSE.
SET ag10       TO FALSE.
SET boostback   TO 0.
SET hdg        TO 0.
SET roll       TO 0.
SET pitch      TO 0.
SET targhdg     TO 0.
SET targpitch   TO 0.
SET targfuel    TO 0.
SET timepitch   TO 0.
SET payloadmass TO 0.
SET cutvel      TO 0.
SET cutheight   TO 0.
SET launch      TO 0.

wait 0.1.
set payloadmass to mass - 158.75.
print"Payload Mass: " + round(payloadmass,1) + "t   ".

set cutvel to 0.0000018*(payloadmass^6) + 8*payloadmass + 680.
set cutheight to (cutvel+10.416)/0.029025.

when boostback >= 0 then {
    set hdg to ship:bearing.
    if hdg <= 0 {
        set hdg to (-1*hdg).
    }
    else if hdg > 0 {
        set hdg to 360 - hdg.
    }.
    set roll to 90 - vectorangle(up:vector,ship:facing:starvector).
    set pitch to 90 - vectorangle(ship:facing:vector,up:vector).
    print"      pitch:" + round(pitch,1) + "deg   " at (0,3).
    print"       roll:" + round(roll,1) + "deg   " at (0,4).
    print"        hdg:" + round(hdg,1) + "hdg   " at (0,5).
    print"    targhdg:" + round(targhdg,1) + "hdg   " at (0,6).
    print"  targpitch:" + round(targpitch,1) + "deg   " at (0,7).
    print"   targfuel:" + round(targfuel,1) + "   " at (0,8).
    print"payloadmass:" + round(payloadmass,1) + "t   " at (0,9).
    print"     cutvel:" + round(cutvel,1) + "m/s   " at (0,10).
    print"  cutheight:" + round(cutheight,1) + "m   " at (0,11).
    print"shipbearing:" + round(ship:bearing,1) + "deg   " at (0,12).
    preserve.
}.

wait until verticalspeed > 100.
set launch to 1.
when launch = 1 then {
    if ship:velocity:surface:mag >= cutvel and
        ship:altitude >= cutheight {
        set targhdg to hdg + 180.
        if targhdg > 360 {
            set targhdg to targhdg - 360.
        }.
        set launch to 2.
    }.
        if stage:liquidfuel <= 350 {
        set targhdg to hdg + 180.
        if targhdg > 360 {
            set targhdg to targhdg - 360.
        }.
        set launch to 2.
    }.
    preserve.
}.
when launch = 2 then {
    set ship:control:pilotmainthrottle to 0.
    lock throttle to 0.
    print"Pressing for stage separation." at (0,2).
    if mass < 62 {
        set launch to 3.
    }.
    preserve.
}.

wait until launch = 3.
sas on.
wait 0.05.
sas off.
gear on.
wait 0.05.
gear off.
brakes on.
wait 0.05.
brakes off.
set boostback to 1.
unlock throttle.
set ship:control:pilotmainthrottle to 0.
ag6 on.

set targpitch to 70 - 0.01*stage:liquidfuel.

rcs on.
unlock steering.
wait 0.05.
sas on.
wait 0.05.
set sasmode to "retrograde".
wait 8.
sas off.
wait 0.05.
lock steering to heading(targhdg,targpitch).
wait 12.
if stage:liquidfuel < 20 {
    set boostback to 3.
}
else if stage:liquidfuel >= 50 {
    set boostback to 2.
    set targfuel to 173 + 0.37*stage:liquidfuel.
}.
wait 0.1.
rcs off.
when boostback = 2 then {
    if stage:liquidfuel > targfuel {
        lock throttle to 1.
    }
    else if stage:liquidfuel - 10 < targfuel {
        set ship:control:pilotmainthrottle to 0.
        lock throttle to 0.
        set boostback to 3.
    }.
    preserve.
}.

wait until boostback = 3.
unlock steering.
unlock throttle.
set ship:control:pilotmainthrottle to 0.
sas off.
wait 0.1.
sas on.
wait 0.1.
rcs on.
set sasmode to "retrograde".

reboot.
wait until mass < 0.