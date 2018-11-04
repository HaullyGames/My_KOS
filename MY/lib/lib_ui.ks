// clearscreen.
GLOBAL ui_announce    IS 0.
GLOBAL ui_announceMsg IS "".
GLOBAL logconsole     IS FALSE. //Save console to log.txt / 0:/<CRAFT NAME>.txt
GLOBAL showInConsole  IS FALSE. //Show in console
GLOBAL init          IS FALSE.

FUNCTION uiConsole {
  PARAMETER prefix.
  PARAMETER msg.
  PARAMETER onlyMessage IS FALSE. // In Console shows only message, but log right entire message.

  LOCAL logtext IS "T+" + ROUND(TIME:SECONDS) + " " + prefix + ": " + msg.
  IF showInConsole OR onlyMessage {
    IF onlyMessage PRINT msg.
    ELSE PRINT logtext.
  }

  IF logconsole {
    IF NOT init {
      DELETEPATH("log.txt").
      SET init TO TRUE.
    }
    LOG logtext TO "log.txt".
    IF HOMECONNECTION:ISCONNECTED {
      COPYPATH("log.txt", "0:/logs/" + SHIP:NAME + ".txt").
    }
  }
}

FUNCTION uiBanner {
  PARAMETER prefix.
  PARAMETER msg.
  PARAMETER sound is 0. // Sound to play when show the message: 1 = Beep, 2 = Chime, 3 = Alert

  IF (TIME:SECONDS - ui_announce > 60) OR (ui_announceMsg <> msg) {
    uiConsole("uiBanner : " + prefix, msg).
    hudtext(msg, 10, 2, 24, GREEN, false).
    SET ui_announce TO TIME:SECONDS.
    SET ui_announceMsg TO msg.
    // Select a sound.
    IF sound = 1 uiBeep().
    ELSE IF sound = 2 uiChime().
    ELSE IF sound = 3 uiAlarm().
  }
}

FUNCTION uiWarning {
  PARAMETER prefix.
  PARAMETER msg.

  uiConsole("uiWarning : " + prefix, msg).
  hudtext(msg, 10, 4, 36, YELLOW, false).
  uiAlarm().
}

FUNCTION uiError {
  PARAMETER prefix.
  PARAMETER msg.

  uiConsole("uiError : " + prefix, msg).
  hudtext(msg, 10, 4, 36, RED, false).
  uiAlarm().
}

FUNCTION uiFatal {
  PARAMETER prefix.
  PARAMETER message.

  uiError(prefix, message + " - RESUME CONTROL").
  WAIT 3.
  REBOOT.
}

FUNCTION uiShowPorts {
  PARAMETER myPort.
  PARAMETER hisPort.
  PARAMETER dist.
  PARAMETER ready.

  IF myPort <> 0 {
    SET ui_myPort:start TO myPort:POSITION.
    LOCAL facing IS 0.
    IF myPort:typename = "DockingPort" {
      SET facing TO myPort:PORTFACING.
    }
    ELSE {
      SET facing TO myPort:FACING.
    }

    SET ui_myPort:VEC TO facing:VECTOR * dist.
    IF ready {
      SET ui_myPort:COLOR TO GREEN.
    } 
    ELSE {
      SET ui_myPort:COLOR TO RED.
    }

    SET ui_myPort:SHOW TO TRUE.
  } 
  ELSE {
    SET ui_myPort:SHOW TO FALSE.
  }

  IF hisPort <> 0 {
    SET ui_hisPort:start TO hisPort:POSITION.
    LOCAL facing IS 0.
    IF hisPort:TYPENAME = "DockingPort" {
      SET facing TO hisPort:PORTFACING.
    }
    ELSE {
      SET facing TO hisPort:FACING.
    }

    SET ui_hisPort:VEC TO facing:VECTOR * dist.
    SET ui_hisPort:show TO TRUE.
  }
  ELSE {
    SET ui_hisPort:SHOW TO FALSE.
  }
}

FUNCTION uiAlarm {
  LOCAL vAlarm TO GetVoice(0).
  SET vAlarm:WAVE TO "TRIANGLE".
  SET vAlarm:VOLUME TO 0.5.
  vAlarm:PLAY(
    LIST(NOTE("A#4", 0.2,  0.25),
         NOTE("A4",  0.2,  0.25),
         NOTE("A#4", 0.2,  0.25),
         NOTE("A4",  0.2,  0.25),
         NOTE("R",   0.2,  0.25),
         NOTE("A#4", 0.2,  0.25),
         NOTE("A4",  0.2,  0.25),
         NOTE("A#4", 0.2,  0.25),
         NOTE("A4",  0.2,  0.25)
    )
  ).
}

FUNCTION uiBeep {
  LOCAL vBeep TO GetVoice(0).
  SET vBeep:VOLUME TO 0.35.
  SET vBeep:WAVE TO "SQUARE".
  vBeep:PLAY(NOTE("A4",0.1, 0.1)).
}

FUNCTION uiChime {
  LOCAL vChimes TO GetVoice(0).
  SET vChimes:VOLUME TO 0.25.
  SET vChimes:WAVE TO "SINE". 
  vChimes:PLAY(
    LIST(NOTE("E5",0.8, 1),
         NOTE("C5",1,1.2)
    )
  ).
}

FUNCTION uiTerminalMenu {
  // Shows a menu in the terminal window and waits for user input.
  // The parameter is a lexicon of a key to be pressed and a text to be show.
  // ie.: 
  // LOCAL MyOptions IS LEXICON("Y","Yes","N","No").
  // LOCAL myVal is uiTerminalMenu(MyOptions).
  //
  // That code will produce a menu with two options, Stay or Go, and will return 1 or 2 depending which key user press.

  PARAMETER Question.
  PARAMETER Options.
  PARAMETER Sound IS 1.
  LOCAL Choice IS 0.
  LOCAL Term IS TERMINAL:INPUT().
  LOCAL showConsole IS TRUE.
  LOCAL ValidSelection IS FALSE.
  UNTIL ValidSelection {
    CLEARSCREEN.
    uiBanner("Terminal","Please choose an option in Terminal.", Sound).
    uiConsole("Terminal", " ", showConsole).
    uiConsole("Terminal", "=================", showConsole).
    uiConsole("Terminal", "Choose an option:", showConsole).
    uiConsole("Terminal", "=================", showConsole).
    uiConsole("Terminal", " ", showConsole).
    uiConsole("Terminal", Question, showConsole).
    FOR Opt IN Options:KEYS {
      uiConsole("Terminal", Opt + ") - " + Options[Opt], showConsole).
    }
    uiConsole("Terminal", "?>", showConsole).

    Term:CLEAR().
    SET Choice TO Term:GETCHAR().
    IF Options:HASKEY(Choice) {
      SET ValidSelection TO TRUE.
      uiConsole("Terminal", "===> " + Options[Choice], showConsole).
    }
    ELSE PRINT "Invalid selection".
  }
  RETURN Choice.
}

FUNCTION uiTerminalList {
  // Shows a menu in the terminal window and waits for user input.

  PARAMETER Question.
  PARAMETER Options.
  PARAMETER Sound IS 2.

  LOCAL Choice IS 0.
  LOCAL answer IS LEXICON().
  LOCAL page IS 0.
  LOCAL KeyPressed IS 0.
  LOCAL Term IS TERMINAL:INPUT().
  LOCAL showConsole IS TRUE.
  LOCAL ValidSelection IS FALSE.

  uiBanner("Terminal","Please make a choice in the Terminal.").
  UNTIL ValidSelection {
    CLEARSCREEN.
    uiConsole("Terminal", " ", showConsole).
    uiConsole("Terminal", Question, showConsole).
    uiConsole("Terminal", "=================", showConsole).
    uiConsole("Terminal", "Choose an option:", showConsole).
    uiConsole("Terminal", "=================", showConsole).
    uiConsole("Terminal", " ", showConsole).
    FROM { LOCAL i IS 10 * page. } UNTIL i = MIN(10 + (10 * page),Options:LENGTH) STEP { SET i TO i+1. } DO {
      uiConsole("Terminal",(i - (10 * page)) + ") - " + Options[i][0], showConsole).
    }
    uiConsole("Terminal", "Showing " + min(Options:LENGTH, 10 + (10 * Page)) + " of " + Options:LENGTH() + " options.", showConsole).
    uiConsole("Terminal", "Use arrows < and > to change pages", showConsole).

    Term:CLEAR().
    SET KeyPressed to Term:GETCHAR().
    IF KeyPressed = Term:RightCursorOne {
      IF Options:LENGTH > 10 + (10 * Page) SET Page TO Page + 1.
    }
    ELSE IF KeyPressed = Term:LeftCursorOne {
      IF Page > 0 SET Page TO Page - 1.
    }
    ELSE IF "0123456789":CONTAINS(KeyPressed) {
      SET Choice TO KeyPressed:ToNumber() + (10 * Page).
      IF Choice < Options:LENGTH {
        SET ValidSelection TO TRUE.
        uiConsole("Terminal", "===> " + Options[Choice], false).
        answer:ADD(Choice,uiTerminalMenu(Options[Choice][0],Options[Choice][1])).
      }
    }
    ELSE uiConsole("Terminal", "Invalid selection", showConsole).
  }
  RETURN answer.
}
