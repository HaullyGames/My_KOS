declare function autostart {
	if not exists("1:autostart.json") {
		print("No autostart info.").
		return.
	}

	print("Will autostart in 10 seconds").
	wait 10.

	SET L TO READJSON("1:autostart.json").
	if L:HASKEY("autostart") {
		set cmd to L["autostart"].
		print("Running autostart command " + cmd).
		if cmd = "rover_autosteer" run rover_autosteer(L).
	}	
}

declare function autostartDelete {
	if exists("1:autostart.json") deletepath("1:autostart.json").
}

declare function autostartExists {
	return exists("1:autostart.json").
}

declare function autostartRoverAutosteer {
	parameter p is lexicon().
	if exists("1:autostart.json") SET L TO READJSON("1:autostart.json").
	else SET L TO LEXICON().
	for key in p:keys {
		if l:haskey(key) l:remove(key).
		l:add(key, p[key]).
	}
	if l:haskey("autostart") l:remove("autostart").
	L:ADD("autostart", "rover_autosteer").
	writejson(l, "1:autostart.json").
}
