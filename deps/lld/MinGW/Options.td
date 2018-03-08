include "llvm/Option/OptParser.td"

class F<string name>: Flag<["--", "-"], name>;
class J<string name>: Joined<["--", "-"], name>;
class S<string name>: Separate<["--", "-"], name>;

def L: JoinedOrSeparate<["-"], "L">, MetaVarName<"<dir>">,
  HelpText<"Add a directory to the library search path">;
def dynamicbase: F<"dynamicbase">, HelpText<"Enable ASLR">;
def entry: S<"entry">, MetaVarName<"<entry>">,
  HelpText<"Name of entry point symbol">;
def export_all_symbols: F<"export-all-symbols">,
    HelpText<"Export all symbols even if a def file or dllexport attributes are used">;
def gc_sections: F<"gc-sections">, HelpText<"Remove unused sections">;
def icf: J<"icf=">, HelpText<"Identical code folding">;
def image_base: S<"image-base">, HelpText<"Base address of the program">;
def l: JoinedOrSeparate<["-"], "l">, MetaVarName<"<libName>">,
  HelpText<"Root name of library to use">;
def m: JoinedOrSeparate<["-"], "m">, HelpText<"Set target emulation">;
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
def stack: S<"stack">;
def strip_all: F<"strip-all">,
    HelpText<"Omit all symbol information from the output binary">;
def whole_archive: F<"whole-archive">,
    HelpText<"Include all object files for following archives">;
def verbose: F<"verbose">, HelpText<"Verbose mode">;

// LLD specific options
def _HASH_HASH_HASH : Flag<["-"], "###">,
    HelpText<"Print (but do not run) the commands to run for this compilation">;
def mllvm: S<"mllvm">;
def Xlink : J<"Xlink=">, MetaVarName<"<arg>">,
    HelpText<"Pass <arg> to the COFF linker">;

// Currently stubs to avoid errors
def Bdynamic: F<"Bdynamic">, HelpText<"Link against shared libraries">;
def Bstatic: F<"Bstatic">, HelpText<"Do not link against shared libraries">;
def O: Joined<["-"], "O">, HelpText<"Optimize output file size">;
def build_id: F<"build-id">;
def disable_auto_image_base: F<"disable-auto-image-base">;
def enable_auto_image_base: F<"enable-auto-image-base">;
def enable_auto_import: F<"enable-auto-import">;
def full_shutdown: Flag<["--"], "full-shutdown">;
def high_entropy_va: F<"high-entropy-va">, HelpText<"Enable 64-bit ASLR">;
def major_image_version: S<"major-image-version">;
def minor_image_version: S<"minor-image-version">;
def no_seh: F<"no-seh">;
def nxcompat: F<"nxcompat">, HelpText<"Enable data execution prevention">;
def pic_executable: F<"pic-executable">;
def sysroot: J<"sysroot">, HelpText<"Sysroot">;
def tsaware: F<"tsaware">, HelpText<"Create Terminal Server aware executable">;
def v: Flag<["-"], "v">, HelpText<"Display the version number">;
def version: F<"version">, HelpText<"Display the version number and exit">;

// Alias
def alias_entry_e: JoinedOrSeparate<["-"], "e">, Alias<entry>;
def alias_strip_s: Flag<["-"], "s">, Alias<strip_all>;
