{
  lib
  , stdenv
  , cmake
  , llvmPackages_17
  , libxml2
  , zlib
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
  sources = readPathsFromFile root (runCommandLocal "parse-cmake" {} ''
    ${gnugrep}/bin/grep -Eo '"[^ ]*(\.c|\.zig)"' ${../CMakeLists.txt} |\
      ${gnugrep}/bin/grep -v 'CMAKE_BINARY_DIR' |\
      ${gnused}/bin/sed 's,''${CMAKE_SOURCE_DIR},.,;s,",,g' > $out
    '');
in with llvmPackages_17; stdenv.mkDerivation {
  name = "zig";

  src = with fileset; toSource {
    inherit root;
    # explicit paths to avoid pointless rebuilds
    fileset = unions ([ ../CMakeLists.txt ] ++ sources);
  };

  outputs = [ "out" ];
  enableParallelBuilding = true;
  hardeningDisable = [ "all" ];
  env.ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/zig-cache";

  nativeBuildInputs = [ cmake llvm.dev ];
  buildInputs = [ libxml2 zlib libclang lld llvm ];

  cmakeFlags = [
    # file RPATH_CHANGE could not write new RPATH
    "-DCMAKE_SKIP_BUILD_RPATH=ON"

    # always link against static build of LLVM
    "-DZIG_STATIC_LLVM=ON"

    # ensure determinism in the compiler build
    "-DZIG_TARGET_MCPU=baseline"

    # do not copy lib so local modifications can be made
    "-DZIG_NO_LIB=ON"
  ];

  meta = {
    homepage = "https://ziglang.org/";
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "zig";
  };
}
