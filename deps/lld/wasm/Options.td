include "llvm/Option/OptParser.td"

// For options whose names are multiple letters, either one dash or
// two can precede the option name except those that start with 'o'.
class F<string name>: Flag<["--", "-"], name>;
class J<string name>: Joined<["--", "-"], name>;
class S<string name>: Separate<["--", "-"], name>;

multiclass Eq<string name> {
  def "": Separate<["--", "-"], name>;
  def _eq: Joined<["--", "-"], name # "=">, Alias<!cast<Separate>(NAME)>;
}

multiclass B<string name, string help1, string help2> {
  def NAME: Flag<["--", "-"], name>, HelpText<help1>;
  def no_ # NAME: Flag<["--", "-"], "no-" # name>, HelpText<help2>;
}

// The follow flags are shared with the ELF linker
def color_diagnostics: F<"color-diagnostics">,
  HelpText<"Use colors in diagnostics">;

def color_diagnostics_eq: J<"color-diagnostics=">,
  HelpText<"Use colors in diagnostics; one of 'always', 'never', 'auto'">;

defm demangle: B<"demangle",
    "Demangle symbol names",
    "Do not demangle symbol names">;

def entry: S<"entry">, MetaVarName<"<entry>">,
  HelpText<"Name of entry point symbol">;

def error_limit: J<"error-limit=">,
  HelpText<"Maximum number of errors to emit before stopping (0 = no limit)">;

def fatal_warnings: F<"fatal-warnings">,
  HelpText<"Treat warnings as errors">;

defm gc_sections: B<"gc-sections",
    "Enable garbage collection of unused sections",
    "Disable garbage collection of unused sections">;

defm merge_data_segments: B<"merge-data-segments",
    "Enable merging data segments",
    "Disable merging data segments">;

def help: F<"help">, HelpText<"Print option help">;

def l: JoinedOrSeparate<["-"], "l">, MetaVarName<"<libName>">,
  HelpText<"Root name of library to use">;

def L: JoinedOrSeparate<["-"], "L">, MetaVarName<"<dir>">,
  HelpText<"Add a directory to the library search path">;

def mllvm: S<"mllvm">, HelpText<"Options to pass to LLVM">;

def no_threads: F<"no-threads">,
  HelpText<"Do not run the linker multi-threaded">;

def no_color_diagnostics: F<"no-color-diagnostics">,
  HelpText<"Do not use colors in diagnostics">;

def no_fatal_warnings: F<"no-fatal-warnings">;

def o: JoinedOrSeparate<["-"], "o">, MetaVarName<"<path>">,
  HelpText<"Path to file to write output">;

def O: JoinedOrSeparate<["-"], "O">, HelpText<"Optimize output file size">;

defm print_gc_sections: B<"print-gc-sections",
    "List removed unused sections",
    "Do not list removed unused sections">;

def relocatable: F<"relocatable">, HelpText<"Create relocatable object file">;

def strip_all: F<"strip-all">, HelpText<"Strip all symbols">;

def strip_debug: F<"strip-debug">, HelpText<"Strip debugging information">;

def threads: F<"threads">, HelpText<"Run the linker multi-threaded">;

defm undefined: Eq<"undefined">,
  HelpText<"Force undefined symbol during linking">;

def v: Flag<["-"], "v">, HelpText<"Display the version number">;

def verbose: F<"verbose">, HelpText<"Verbose mode">;

def version: F<"version">, HelpText<"Display the version number and exit">;

def z: JoinedOrSeparate<["-"], "z">, MetaVarName<"<option>">,
  HelpText<"Linker option extensions">;

// The follow flags are unique to wasm

def allow_undefined: F<"allow-undefined">,
  HelpText<"Allow undefined symbols in linked binary">;

def allow_undefined_file: J<"allow-undefined-file=">,
  HelpText<"Allow symbols listed in <file> to be undefined in linked binary">;

def allow_undefined_file_s: Separate<["-"], "allow-undefined-file">,
  Alias<allow_undefined_file>;

defm export: Eq<"export">,
  HelpText<"Force a symbol to be exported">;

def export_all: F<"export-all">,
  HelpText<"Export all symbols (normally combined with --no-gc-sections)">;

def export_table: F<"export-table">,
  HelpText<"Export function table to the environment">;

def global_base: J<"global-base=">,
  HelpText<"Where to start to place global data">;

def import_memory: F<"import-memory">,
  HelpText<"Import memory from the environment">;

def import_table: F<"import-table">,
  HelpText<"Import function table from the environment">;

def initial_memory: J<"initial-memory=">,
  HelpText<"Initial size of the linear memory">;

def max_memory: J<"max-memory=">,
  HelpText<"Maximum size of the linear memory">;

def no_entry: F<"no-entry">,
  HelpText<"Do not output any entry point">;

def stack_first: F<"stack-first">,
  HelpText<"Place stack at start of linear memory rather than after data">;

defm whole_archive: B<"whole-archive",
    "Force load of all members in a static library",
    "Do not force load of all members in a static library (default)">;

// Aliases
def alias_entry_e: JoinedOrSeparate<["-"], "e">, Alias<entry>;
def alias_entry_entry: J<"entry=">, Alias<entry>;
def alias_initial_memory_i: Flag<["-"], "i">, Alias<initial_memory>;
def alias_max_memory_m: Flag<["-"], "m">, Alias<max_memory>;
def alias_relocatable_r: Flag<["-"], "r">, Alias<relocatable>;
def alias_undefined_u: JoinedOrSeparate<["-"], "u">, Alias<undefined>;

// LTO-related options.
def lto_O: J<"lto-O">, MetaVarName<"<opt-level>">,
  HelpText<"Optimization level for LTO">;
def lto_partitions: J<"lto-partitions=">,
  HelpText<"Number of LTO codegen partitions">;
def disable_verify: F<"disable-verify">;
def save_temps: F<"save-temps">;
def thinlto_cache_dir: J<"thinlto-cache-dir=">,
  HelpText<"Path to ThinLTO cached object file directory">;
defm thinlto_cache_policy: Eq<"thinlto-cache-policy">,
  HelpText<"Pruning policy for the ThinLTO cache">;
def thinlto_jobs: J<"thinlto-jobs=">, HelpText<"Number of ThinLTO jobs">;
