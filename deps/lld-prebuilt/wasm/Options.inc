/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Option Parsing Definitions                                                 *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

/////////
// Prefixes

#ifdef PREFIX
#define COMMA ,
PREFIX(prefix_0, {nullptr})
PREFIX(prefix_2, {"-" COMMA nullptr})
PREFIX(prefix_1, {"--" COMMA "-" COMMA nullptr})
#undef COMMA
#endif // PREFIX

/////////
// Groups

#ifdef OPTION

//////////
// Options

OPTION(prefix_0, "<input>", INPUT, Input, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_0, "<unknown>", UNKNOWN, Unknown, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "allow-undefined-file=", allow_undefined_file, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Allow symbols listed in <file> to be undefined in linked binary", nullptr, nullptr)
OPTION(prefix_2, "allow-undefined-file", allow_undefined_file_s, Separate, INVALID, allow_undefined_file, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "allow-undefined", allow_undefined, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Allow undefined symbols in linked binary", nullptr, nullptr)
OPTION(prefix_1, "check-signatures", check_signatures, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Check function signatures", nullptr, nullptr)
OPTION(prefix_1, "color-diagnostics=", color_diagnostics_eq, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_1, "color-diagnostics", color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_1, "emit-relocs", emit_relocs, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Generate relocations in output", nullptr, nullptr)
OPTION(prefix_1, "entry=", alias_entry_entry, Joined, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "entry", entry, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Name of entry point symbol", "<entry>", nullptr)
OPTION(prefix_1, "error-limit=", error_limit, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", nullptr, nullptr)
OPTION(prefix_2, "e", alias_entry_e, JoinedOrSeparate, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "global-base=", global_base, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Where to start to place global data", nullptr, nullptr)
OPTION(prefix_1, "help", help, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print option help", nullptr, nullptr)
OPTION(prefix_1, "import-memory", import_memory, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Import memory from the environment", nullptr, nullptr)
OPTION(prefix_1, "initial-memory=", initial_memory, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Initial size of the linear memory", nullptr, nullptr)
OPTION(prefix_2, "i", alias_initial_memory_i, Flag, INVALID, initial_memory, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "L", L, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Add a directory to the library search path", "<dir>", nullptr)
OPTION(prefix_2, "l", l, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Root name of library to use", "<libName>", nullptr)
OPTION(prefix_1, "max-memory=", max_memory, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Maximum size of the linear memory", nullptr, nullptr)
OPTION(prefix_1, "mllvm", mllvm, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Options to pass to LLVM", nullptr, nullptr)
OPTION(prefix_2, "m", alias_max_memory_m, Flag, INVALID, max_memory, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "no-check-signatures", no_check_signatures, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Don't check function signatures", nullptr, nullptr)
OPTION(prefix_1, "no-color-diagnostics", no_color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_1, "no-entry", no_entry, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not output any entry point", nullptr, nullptr)
OPTION(prefix_1, "no-threads", no_threads, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not run the linker multi-threaded", nullptr, nullptr)
OPTION(prefix_2, "o", o, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Path to file to write output", "<path>", nullptr)
OPTION(prefix_1, "relocatable", relocatable, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create relocatable object file", nullptr, nullptr)
OPTION(prefix_2, "r", alias_relocatable_r, Flag, INVALID, relocatable, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "strip-all", strip_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip all symbols", nullptr, nullptr)
OPTION(prefix_1, "strip-debug", strip_debug, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip debugging information", nullptr, nullptr)
OPTION(prefix_1, "threads", threads, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Run the linker multi-threaded", nullptr, nullptr)
OPTION(prefix_1, "undefined=", undefined_eq, Joined, INVALID, undefined, nullptr, 0, 0,
       "Force undefined symbol during linking", nullptr, nullptr)
OPTION(prefix_1, "undefined", undefined, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Force undefined symbol during linking", nullptr, nullptr)
OPTION(prefix_2, "u", alias_undefined_u, JoinedOrSeparate, INVALID, undefined, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "verbose", verbose, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Verbose mode", nullptr, nullptr)
OPTION(prefix_1, "version", version, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number and exit", nullptr, nullptr)
OPTION(prefix_2, "v", v, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number", nullptr, nullptr)
OPTION(prefix_2, "z", z, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Linker option extensions", "<option>", nullptr)
#endif // OPTION

#ifdef OPTTABLE_ARG_INIT
//////////
// Option Values


#endif // OPTTABLE_ARG_INIT
