// Return parts resources detail
FUNCTION resourceLexFromPart {
  PARAMETER p.                  // Part searched

  LOCAL rlex IS LEXICON().
  LOCAL tmp  IS LEXICON().
  FOR res IN p:RESOURCES {
    SET tmp["DENSITY"]  TO res:DENSITY.
    SET tmp["AMOUNT"]   TO res:AMOUNT.
    SET tmp["CAPACITY"] TO res:CAPACITY.
    SET rlex[res:NAME]  TO tmp:COPY.
  }
  RETURN rlex:COPY.
}

// Return parts resource detail including children parts.
FUNCTION resourcesIncludingChildren {
  PARAMETER p.
  LOCAL res IS resourceLexFromPart(p).
  FOR c IN p:CHILDREN:COPY {
    LOCAL cres IS resourcesIncludingChildren(c).
    FOR r IN cres:KEYS {
      IF res:HASKEY(r) {
        SET res[r]["AMOUNT"]   TO cres[r]["AMOUNT"] +   res[r]["AMOUNT"].
        SET res[r]["CAPACITY"] TO cres[r]["CAPACITY"] + res[r]["CAPACITY"].
      } 
      ELSE {
        SET res[r] to cres[r]:COPY.
      }
    }
  }
  RETURN res:COPY.
}