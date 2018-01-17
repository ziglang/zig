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

def L: JoinedOrSeparate<["-"], "L">, MetaVarName<"<dir>">,
  HelpText<"Add a directory to the library search path">;

def color_diagnostics: F<"color-diagnostics">,
  HelpText<"Use colors in diagnostics">;

def color_diagnostics_eq: J<"color-diagnostics=">,
  HelpText<"Use colors in diagnostics">;

// The follow flags are shared with the ELF linker
def help: F<"help">, HelpText<"Print option help">;

def l: JoinedOrSeparate<["-"], "l">, MetaVarName<"<libName>">,
  HelpText<"Root name of library to use">;

def mllvm: S<"mllvm">, HelpText<"Options to pass to LLVM">;

def no_threads: F<"no-threads">,
  HelpText<"Do not run the linker multi-threaded">;

def no_color_diagnostics: F<"no-color-diagnostics">,
  HelpText<"Do not use colors in diagnostics">;

def no_check_signatures: F<"no-check-signatures">, HelpText<"Don't check function signatures">;

def o: JoinedOrSeparate<["-"], "o">, MetaVarName<"<path>">,
  HelpText<"Path to file to write output">;

def threads: F<"threads">, HelpText<"Run the linker multi-threaded">;

def check_signatures: F<"check-signatures">, HelpText<"Check function signatures">;

def v: Flag<["-"], "v">, HelpText<"Display the version number">;

def version: F<"version">, HelpText<"Display the version number and exit">;

def verbose: F<"verbose">, HelpText<"Verbose mode">;

def relocatable: F<"relocatable">, HelpText<"Create relocatable object file">;

def emit_relocs: F<"emit-relocs">, HelpText<"Generate relocations in output">;

def strip_all: F<"strip-all">, HelpText<"Strip all symbols">;

def strip_debug: F<"strip-debug">, HelpText<"Strip debugging information">;

defm undefined: Eq<"undefined">,
  HelpText<"Force undefined symbol during linking">;

def z: JoinedOrSeparate<["-"], "z">, MetaVarName<"<option>">,
  HelpText<"Linker option extensions">;

def entry: S<"entry">, MetaVarName<"<entry>">,
  HelpText<"Name of entry point symbol">;

def no_entry: F<"no-entry">,
  HelpText<"Do not output any entry point">;

def error_limit: J<"error-limit=">,
  HelpText<"Maximum number of errors to emit before stopping (0 = no limit)">;

// The follow flags are unique to wasm

def global_base: J<"global-base=">,
  HelpText<"Where to start to place global data">;

def initial_memory: J<"initial-memory=">,
  HelpText<"Initial size of the linear memory">;

def max_memory: J<"max-memory=">,
  HelpText<"Maximum size of the linear memory">;

def import_memory: F<"import-memory">,
  HelpText<"Import memory from the environment">;

def allow_undefined: F<"allow-undefined">,
  HelpText<"Allow undefined symbols in linked binary">;

def allow_undefined_file: J<"allow-undefined-file=">,
  HelpText<"Allow symbols listed in <file> to be undefined in linked binary">;

def allow_undefined_file_s: Separate<["-"], "allow-undefined-file">, Alias<allow_undefined_file>;

// Aliases
def alias_initial_memory_i: Flag<["-"], "i">, Alias<initial_memory>;
def alias_max_memory_m: Flag<["-"], "m">, Alias<max_memory>;
def alias_relocatable_r: Flag<["-"], "r">, Alias<relocatable>;
def alias_entry_e: JoinedOrSeparate<["-"], "e">, Alias<entry>;
def alias_entry_entry: J<"entry=">, Alias<entry>;
def alias_undefined_u: JoinedOrSeparate<["-"], "u">, Alias<undefined>;
