//Print system info; wait for all parts to load

IF HOMECONNECTION:ISCONNECTED {
  IF NOT EXISTS("1:/lib") CREATEDIR("1:/lib").
  copypath("0:/craneland.ks", "1:").
  copypath("0:/lib/lib_ui.ks", "1:/lib").
  copypath("0:/lib/lib_parts.ks", "1:/lib").
  copypath("0:/lib/lib_staging.ks", "1:/lib").
}

set stopped to false.

declare function execute {
  parameter command.

  if command:startswith("run ") {
    runpath(command:remove(0, 4)).
  }
  if command = "stop" set stopped to true.
}

print("Waiting for messages.").

until stopped {
  if not ship:messages:empty {
    set msg to ship:messages:pop.
    print("Received message: " + msg:content).
    execute(msg:content).
  }
  wait 0.
}
