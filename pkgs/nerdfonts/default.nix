{ stdenvNoCC
, fetchurl
, lib
}:
let
  naming = import ./naming.nix { inherit lib; };

  # both of these files are generated via ./update.sh
  version = import ./version.nix;
  fontsShas = import ./shas.nix;

  fontNames = builtins.attrNames fontsShas;
  getSrc =
    version: fontName:
    fetchurl {
      url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${fontName}.tar.xz";
      sha256 = fontsShas.${fontName};
    };
  mkPackage =
    fontName:
    stdenvNoCC.mkDerivation {
      inherit version;
      pname = naming.getPname fontName;
      sourceRoot = ".";
      src = getSrc version fontName;
      installPhase = ''
        runHook preInstall

        find -name \*.otf -exec install -Dm644 -t $out/share/fonts/opentype/NerdFonts {} \;
        find -name \*.ttf -exec install -Dm644 -t $out/share/fonts/truetype/NerdFonts {} \;

        runHook postInstall
      '';
      meta = with lib; {
        description = "${fontName} font patched with 3,600+ icons";
        longDescription = ''
          Nerd Fonts is a project that attempts to patch as many developer targeted
          and/or used fonts as possible. The patch is to specifically add a high
          number of additional glyphs from popular 'iconic fonts' such as Font
          Awesome, Devicons, Octicons, and others.
        '';
        homepage = "https://nerdfonts.com/";
        license = licenses.mit;
        hydraPlatforms = []; # 'Output limit exceeded' on Hydra
      };
    };
in
  builtins.listToAttrs
    (map
      (fontName: { name = naming.getAttrName fontName; value = mkPackage fontName; })
      fontNames)

