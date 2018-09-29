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
OPTION(prefix_1, "color-diagnostics=", color_diagnostics_eq, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics; one of 'always', 'never', 'auto'", nullptr, nullptr)
OPTION(prefix_1, "color-diagnostics", color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_1, "demangle", demangle, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Demangle symbol names", nullptr, nullptr)
OPTION(prefix_1, "disable-verify", disable_verify, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "entry=", alias_entry_entry, Joined, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "entry", entry, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Name of entry point symbol", "<entry>", nullptr)
OPTION(prefix_1, "error-limit=", error_limit, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", nullptr, nullptr)
OPTION(prefix_1, "export-all", export_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Export all symbols (normally combined with --no-gc-sections)", nullptr, nullptr)
OPTION(prefix_1, "export-table", export_table, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Export function table to the environment", nullptr, nullptr)
OPTION(prefix_1, "export=", export_eq, Joined, INVALID, export, nullptr, 0, 0,
       "Force a symbol to be exported", nullptr, nullptr)
OPTION(prefix_1, "export", export, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Force a symbol to be exported", nullptr, nullptr)
OPTION(prefix_2, "e", alias_entry_e, JoinedOrSeparate, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "fatal-warnings", fatal_warnings, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Treat warnings as errors", nullptr, nullptr)
OPTION(prefix_1, "gc-sections", gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable garbage collection of unused sections", nullptr, nullptr)
OPTION(prefix_1, "global-base=", global_base, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Where to start to place global data", nullptr, nullptr)
OPTION(prefix_1, "help", help, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print option help", nullptr, nullptr)
OPTION(prefix_1, "import-memory", import_memory, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Import memory from the environment", nullptr, nullptr)
OPTION(prefix_1, "import-table", import_table, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Import function table from the environment", nullptr, nullptr)
OPTION(prefix_1, "initial-memory=", initial_memory, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Initial size of the linear memory", nullptr, nullptr)
OPTION(prefix_2, "i", alias_initial_memory_i, Flag, INVALID, initial_memory, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "lto-O", lto_O, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Optimization level for LTO", "<opt-level>", nullptr)
OPTION(prefix_1, "lto-partitions=", lto_partitions, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Number of LTO codegen partitions", nullptr, nullptr)
OPTION(prefix_2, "L", L, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Add a directory to the library search path", "<dir>", nullptr)
OPTION(prefix_2, "l", l, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Root name of library to use", "<libName>", nullptr)
OPTION(prefix_1, "max-memory=", max_memory, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Maximum size of the linear memory", nullptr, nullptr)
OPTION(prefix_1, "merge-data-segments", merge_data_segments, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable merging data segments", nullptr, nullptr)
OPTION(prefix_1, "mllvm", mllvm, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Options to pass to LLVM", nullptr, nullptr)
OPTION(prefix_2, "m", alias_max_memory_m, Flag, INVALID, max_memory, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "no-color-diagnostics", no_color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_1, "no-demangle", no_demangle, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not demangle symbol names", nullptr, nullptr)
OPTION(prefix_1, "no-entry", no_entry, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not output any entry point", nullptr, nullptr)
OPTION(prefix_1, "no-fatal-warnings", no_fatal_warnings, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "no-gc-sections", no_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable garbage collection of unused sections", nullptr, nullptr)
OPTION(prefix_1, "no-merge-data-segments", no_merge_data_segments, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable merging data segments", nullptr, nullptr)
OPTION(prefix_1, "no-print-gc-sections", no_print_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not list removed unused sections", nullptr, nullptr)
OPTION(prefix_1, "no-threads", no_threads, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not run the linker multi-threaded", nullptr, nullptr)
OPTION(prefix_1, "no-whole-archive", no_whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not force load of all members in a static library (default)", nullptr, nullptr)
OPTION(prefix_2, "O", O, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Optimize output file size", nullptr, nullptr)
OPTION(prefix_2, "o", o, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Path to file to write output", "<path>", nullptr)
OPTION(prefix_1, "print-gc-sections", print_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "List removed unused sections", nullptr, nullptr)
OPTION(prefix_1, "relocatable", relocatable, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create relocatable object file", nullptr, nullptr)
OPTION(prefix_2, "r", alias_relocatable_r, Flag, INVALID, relocatable, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "save-temps", save_temps, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "stack-first", stack_first, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Place stack at start of linear memory rather than after data", nullptr, nullptr)
OPTION(prefix_1, "strip-all", strip_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip all symbols", nullptr, nullptr)
OPTION(prefix_1, "strip-debug", strip_debug, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip debugging information", nullptr, nullptr)
OPTION(prefix_1, "thinlto-cache-dir=", thinlto_cache_dir, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Path to ThinLTO cached object file directory", nullptr, nullptr)
OPTION(prefix_1, "thinlto-cache-policy=", thinlto_cache_policy_eq, Joined, INVALID, thinlto_cache_policy, nullptr, 0, 0,
       "Pruning policy for the ThinLTO cache", nullptr, nullptr)
OPTION(prefix_1, "thinlto-cache-policy", thinlto_cache_policy, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Pruning policy for the ThinLTO cache", nullptr, nullptr)
OPTION(prefix_1, "thinlto-jobs=", thinlto_jobs, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Number of ThinLTO jobs", nullptr, nullptr)
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
OPTION(prefix_1, "whole-archive", whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Force load of all members in a static library", nullptr, nullptr)
OPTION(prefix_2, "z", z, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Linker option extensions", "<option>", nullptr)
#endif // OPTION

#ifdef OPTTABLE_ARG_INIT
//////////
// Option Values


#endif // OPTTABLE_ARG_INIT
