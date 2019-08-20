include "llvm/Option/OptParser.td"

class F<string name>: Flag<["--", "-"], name>;
class J<string name>: Joined<["--", "-"], name>;
class S<string name>: Separate<["--", "-"], name>;

def L: JoinedOrSeparate<["-"], "L">, MetaVarName<"<dir>">,
  HelpText<"Add a directory to the library search path">;
def Bdynamic: F<"Bdynamic">, HelpText<"Link against shared libraries">;
def Bstatic: F<"Bstatic">, HelpText<"Do not link against shared libraries">;
def dynamicbase: F<"dynamicbase">, HelpText<"Enable ASLR">;
def entry: S<"entry">, MetaVarName<"<entry>">,
  HelpText<"Name of entry point symbol">;
def exclude_all_symbols: F<"exclude-all-symbols">,
    HelpText<"Don't automatically export any symbols">;
def export_all_symbols: F<"export-all-symbols">,
    HelpText<"Export all symbols even if a def file or dllexport attributes are used">;
def gc_sections: F<"gc-sections">, HelpText<"Remove unused sections">;
def help: F<"help">, HelpText<"Print option help">;
def icf: J<"icf=">, HelpText<"Identical code folding">;
def image_base: S<"image-base">, HelpText<"Base address of the program">;
def insert_timestamp: F<"insert-timestamp">,
    HelpText<"Include PE header timestamp">;
def kill_at: F<"kill-at">, HelpText<"Remove @n from exported symbols">;
def l: JoinedOrSeparate<["-"], "l">, MetaVarName<"<libName>">,
  HelpText<"Root name of library to use">;
def m: JoinedOrSeparate<["-"], "m">, HelpText<"Set target emulation">;
def major_os_version: Separate<["--"], "major-os-version">,
    HelpText<"Set the OS and subsystem major version">;
def major_os_version_eq: Joined<["--"], "major-os-version=">,
    Alias<major_os_version>;
def major_subsystem_version: Separate<["--"], "major-subsystem-version">,
    HelpText<"Set the OS and subsystem major version">;
def major_subsystem_version_eq: Joined<["--"], "major-subsystem-version=">,
    Alias<major_subsystem_version>;
def map: S<"Map">, HelpText<"Output a linker map">;
def map_eq: J<"Map=">, Alias<map>;
def minor_os_version: Separate<["--"], "minor-os-version">,
    HelpText<"Set the OS and subsystem minor version">;
def minor_os_version_eq: Joined<["--"], "minor-os-version=">,
    Alias<minor_os_version>;
def minor_subsystem_version: Separate<["--"], "minor-subsystem-version">,
    HelpText<"Set the OS and subsystem minor version">;
def minor_subsystem_version_eq: Joined<["--"], "minor-subsystem-version=">,
    Alias<minor_subsystem_version>;
def no_insert_timestamp: F<"no-insert-timestamp">,
    HelpText<"Don't include PE header timestamp">;
def no_whole_archive: F<"no-whole-archive">,
    HelpText<"No longer include all object files for following archives">;
def large_address_aware: Flag<["--"], "large-address-aware">,
    HelpText<"Enable large addresses">;
def no_gc_sections: F<"no-gc-sections">, HelpText<"Don't remove unused sections">;
def o: JoinedOrSeparate<["-"], "o">, MetaVarName<"<path>">,
  HelpText<"Path to file to write output">;
def out_implib: Separate<["--"], "out-implib">, HelpText<"Import library name">;
def out_implib_eq: Joined<["--"], "out-implib=">, Alias<out_implib>;
def output_def: S<"output-def">, HelpText<"Output def file">;
def shared: F<"shared">, HelpText<"Build a shared object">;
def subs: S<"subsystem">, HelpText<"Specify subsystem">;
def subs_eq: J<"subsystem=">, Alias<subs>;
def stack: S<"stack">;
def strip_all: F<"strip-all">,
    HelpText<"Omit all symbol information from the output binary">;
def strip_debug: F<"strip-debug">,
    HelpText<"Omit all debug information, but keep symbol information">;
def undefined: S<"u">,
    HelpText<"Include symbol in the link, if available">;
def undefined_long: S<"undefined">, Alias<undefined>;
def undefined_eq: J<"undefined=">, Alias<undefined>;
def whole_archive: F<"whole-archive">,
    HelpText<"Include all object files for following archives">;
def v: Flag<["-"], "v">, HelpText<"Display the version number">;
def verbose: F<"verbose">, HelpText<"Verbose mode">;
def version: F<"version">, HelpText<"Display the version number and exit">;
def require_defined: S<"require-defined">,
    HelpText<"Force symbol to be added to symbol table as an undefined one">;
def require_defined_eq: J<"require-defined=">, Alias<require_defined>;

// LLD specific options
def _HASH_HASH_HASH : Flag<["-"], "###">,
    HelpText<"Print (but do not run) the commands to run for this compilation">;
def appcontainer: F<"appcontainer">, HelpText<"Set the appcontainer flag in the executable">;
def delayload: S<"delayload">, HelpText<"DLL to load only on demand">;
def delayload_eq: J<"delayload=">, Alias<delayload>;
def mllvm: S<"mllvm">;
def pdb: S<"pdb">, HelpText<"Output PDB debug info file, chosen implicitly if the argument is empty">;
def pdb_eq: J<"pdb=">, Alias<pdb>;
def Xlink : J<"Xlink=">, MetaVarName<"<arg>">,
    HelpText<"Pass <arg> to the COFF linker">;

// Alias
def alias_entry_e: JoinedOrSeparate<["-"], "e">, Alias<entry>;
def alias_strip_s: Flag<["-"], "s">, Alias<strip_all>;
def alias_strip_S: Flag<["-"], "S">, Alias<strip_debug>;

// Ignored options
def: Joined<["-"], "O">;
def: F<"build-id">;
def: F<"disable-auto-image-base">;
def: F<"enable-auto-image-base">;
def: F<"enable-auto-import">, HelpText<"Ignored; listed for libtool compatibility">;
def: F<"end-group">;
def: Flag<["--"], "full-shutdown">;
def: F<"high-entropy-va">;
def: S<"major-image-version">;
def: S<"minor-image-version">;
def: F<"no-seh">;
def: F<"nxcompat">;
def: F<"pic-executable">;
def: S<"plugin">;
def: J<"plugin=">;
def: S<"plugin-opt">;
def: J<"plugin-opt=">;
def: J<"sysroot">;
def: F<"start-group">;
def: F<"tsaware">;
