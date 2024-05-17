{ lib }:
rec {
  fixFirstDigitChar =
    let
      getAttrsFromList =
        list:
        builtins.listToAttrs
          (map (elem: { name = elem; value = null; }) list);
      digitChars = getAttrsFromList (lib.strings.stringToCharacters "0123456789");
    in
      string:
      let
        firstChar = builtins.substring 0 1 string;
      in
        if builtins.hasAttr firstChar digitChars then
          "_" + string
        else
          string;
  fixUpperCharToLowerChar =
    let
      upperToLowerChars =
        builtins.listToAttrs
          (lib.lists.zipListsWith
            (upper: lower: { name = upper; value = lower; })
            lib.strings.upperChars
            lib.strings.lowerChars);
      getFirstChar =
        char:
        if (builtins.hasAttr char upperToLowerChars) then
          upperToLowerChars.${char}
        else
          char;
      getRestSection =
        leftChar: rightChar:
        if (builtins.hasAttr rightChar upperToLowerChars) then
          let
            lowerChar = upperToLowerChars.${rightChar};
          in
            if (!(builtins.hasAttr leftChar upperToLowerChars)
            && (leftChar != "-" )) then
              "-" + lowerChar
            else
              lowerChar
        else
          rightChar;
    in
      string:
      let
        newFirstChar = getFirstChar (builtins.substring 0 1 string);
        length1 = (builtins.stringLength string) - 1;
        leftChars = lib.strings.stringToCharacters (builtins.substring 0 length1 string);
        rightChars = lib.strings.stringToCharacters (builtins.substring 1 length1 string);
        restSections = lib.lists.zipListsWith getRestSection leftChars rightChars;
      in builtins.foldl' (acc: elem: acc + elem) newFirstChar restSections;
  getTempName =
    let
      exceptions = {
        "0xProto" = "0xproto";
        "DejaVuSansMono" = "dejavu-sans-mono";
        "IBMPlexMono" = "ibm-plex-mono";
        "JetBrainsMono" = "jetbrains-mono";
        "MPlus" = "m-plus";
        "NerdFontsSymbolsOnly" = "nerdfonts-symbols-only";
        "iA-Writer" = "ia-writer";
        "ProFont" = "profont";
      };
    in
      fontName:
      if builtins.hasAttr fontName exceptions then
        exceptions."${fontName}"
      else
        fixUpperCharToLowerChar fontName;
  getPname = fontName: (getTempName fontName) + "-nerdfont";
  getAttrName = fontName: fixFirstDigitChar (getTempName fontName);
}
