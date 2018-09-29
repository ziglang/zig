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
PREFIX(prefix_1, {"-" COMMA nullptr})
PREFIX(prefix_3, {"--" COMMA nullptr})
PREFIX(prefix_2, {"--" COMMA "-" COMMA nullptr})
#undef COMMA
#endif // PREFIX

/////////
// Groups

#ifdef OPTION

//////////
// Options

OPTION(prefix_0, "<input>", INPUT, Input, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_0, "<unknown>", UNKNOWN, Unknown, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "###", _HASH_HASH_HASH, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print (but do not run) the commands to run for this compilation", nullptr, nullptr)
OPTION(prefix_2, "Bdynamic", Bdynamic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Link against shared libraries", nullptr, nullptr)
OPTION(prefix_2, "Bstatic", Bstatic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not link against shared libraries", nullptr, nullptr)
OPTION(prefix_2, "build-id", build_id, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "disable-auto-image-base", disable_auto_image_base, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "dynamicbase", dynamicbase, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable ASLR", nullptr, nullptr)
OPTION(prefix_2, "enable-auto-image-base", enable_auto_image_base, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "enable-auto-import", enable_auto_import, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "end-group", end_group, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "entry", entry, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Name of entry point symbol", "<entry>", nullptr)
OPTION(prefix_2, "export-all-symbols", export_all_symbols, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Export all symbols even if a def file or dllexport attributes are used", nullptr, nullptr)
OPTION(prefix_1, "e", alias_entry_e, JoinedOrSeparate, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "full-shutdown", full_shutdown, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "gc-sections", gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Remove unused sections", nullptr, nullptr)
OPTION(prefix_2, "high-entropy-va", high_entropy_va, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable 64-bit ASLR", nullptr, nullptr)
OPTION(prefix_2, "icf=", icf, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Identical code folding", nullptr, nullptr)
OPTION(prefix_2, "image-base", image_base, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Base address of the program", nullptr, nullptr)
OPTION(prefix_2, "kill-at", kill_at, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Remove @n from exported symbols", nullptr, nullptr)
OPTION(prefix_3, "large-address-aware", large_address_aware, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable large addresses", nullptr, nullptr)
OPTION(prefix_1, "L", L, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Add a directory to the library search path", "<dir>", nullptr)
OPTION(prefix_1, "l", l, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Root name of library to use", "<libName>", nullptr)
OPTION(prefix_2, "major-image-version", major_image_version, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Map=", map_eq, Joined, INVALID, map, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Map", map, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Output a linker map", nullptr, nullptr)
OPTION(prefix_2, "minor-image-version", minor_image_version, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "mllvm", mllvm, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "m", m, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Set target emulation", nullptr, nullptr)
OPTION(prefix_2, "no-gc-sections", no_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Don't remove unused sections", nullptr, nullptr)
OPTION(prefix_2, "no-seh", no_seh, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-whole-archive", no_whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "No longer include all object files for following archives", nullptr, nullptr)
OPTION(prefix_2, "nxcompat", nxcompat, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable data execution prevention", nullptr, nullptr)
OPTION(prefix_3, "out-implib=", out_implib_eq, Joined, INVALID, out_implib, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "out-implib", out_implib, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Import library name", nullptr, nullptr)
OPTION(prefix_2, "output-def", output_def, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Output def file", nullptr, nullptr)
OPTION(prefix_1, "O", O, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Optimize output file size", nullptr, nullptr)
OPTION(prefix_1, "o", o, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Path to file to write output", "<path>", nullptr)
OPTION(prefix_2, "pdb", pdb, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify output PDB debug information file", nullptr, nullptr)
OPTION(prefix_2, "pic-executable", pic_executable, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "shared", shared, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Build a shared object", nullptr, nullptr)
OPTION(prefix_2, "stack", stack, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "start-group", start_group, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "strip-all", strip_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Omit all symbol information from the output binary", nullptr, nullptr)
OPTION(prefix_2, "strip-debug", strip_debug, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Omit all debug information, but keep symbol information", nullptr, nullptr)
OPTION(prefix_2, "subsystem", subs, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify subsystem", nullptr, nullptr)
OPTION(prefix_2, "sysroot", sysroot, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Sysroot", nullptr, nullptr)
OPTION(prefix_1, "S", alias_strip_S, Flag, INVALID, strip_debug, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "s", alias_strip_s, Flag, INVALID, strip_all, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "tsaware", tsaware, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create Terminal Server aware executable", nullptr, nullptr)
OPTION(prefix_2, "verbose", verbose, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Verbose mode", nullptr, nullptr)
OPTION(prefix_2, "version", version, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number and exit", nullptr, nullptr)
OPTION(prefix_1, "v", v, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number", nullptr, nullptr)
OPTION(prefix_2, "whole-archive", whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Include all object files for following archives", nullptr, nullptr)
OPTION(prefix_2, "Xlink=", Xlink, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Pass <arg> to the COFF linker", "<arg>", nullptr)
#endif // OPTION

#ifdef OPTTABLE_ARG_INIT
//////////
// Option Values


#endif // OPTTABLE_ARG_INIT
