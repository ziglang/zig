{
  lib
  , stdenv
  , runCommandLocal
  , gnugrep
  , gnused
}:

with builtins;
with lib;

let
  readPathsFromFile =
    (rootPath: file:
      let
        lines = lib.splitString "\n" (readFile file);
        absolutePaths = map (path: rootPath + "/${path}") lines;
      in
        absolutePaths);

  root = ./..;

  # does not resolve imports from .zig files so might have to still manually include subpaths
  source_deps = readPathsFromFile root (runCommandLocal "parse-bootstrap-c" {} ''
    ${gnugrep}/bin/grep -Eo '"[^ ]*/[^ ]*(\.c|\.zig)"' ${../bootstrap.c} |\
      ${gnused}/bin/sed 's,",,g' > $out
    '');

  # https://github.com/nix-community/home-manager/blob/master/modules/lib/strings.nix
  storeFileName = path:
    let
      # All characters that are considered safe. Note "-" is not
      # included to avoid "-" followed by digit being interpreted as a
      # version.
      safeChars = [ "+" "." "_" "?" "=" ] ++ lowerChars ++ upperChars
        ++ stringToCharacters "0123456789";

      empties = l: genList (x: "") (length l);

      unsafeInName =
        stringToCharacters (replaceStrings safeChars (empties safeChars) path);

      safeName = replaceStrings unsafeInName (empties unsafeInName) path;
    in "zig_" + safeName;

  mkOutOfStoreSymlink = path: let
    pathStr = toString path;
    name = storeFileName (baseNameOf pathStr);
  in
    runCommandLocal name {} ''ln -s ${escapeShellArg pathStr} $out'';
in stdenv.mkDerivation {
  name = "zig";

  src = with fileset; toSource {
    root = ./..;
    # explicit paths to avoid pointless rebuilds
    fileset = unions ([ ../bootstrap.c ../src ../lib/compiler_rt ../deps/aro ] ++ source_deps);
  };

  outputs = [ "out" ];
  hardeningDisable = [ "all" ];
  env.ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/zig-cache";

  buildPhase = ''
    cc -o bootstrap bootstrap.c
    ./bootstrap
    '';

  installPhase = ''
    install -Dm755 zig2 $out/bin/zig
    ln -s ${mkOutOfStoreSymlink (toString ../lib)} $out/bin/lib
    '';

  meta = {
    homepage = "https://ziglang.org/";
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "zig";
  };
}
