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
PREFIX(prefix_2, {"-" COMMA "--" COMMA nullptr})
#undef COMMA
#endif // PREFIX

/////////
// Groups

#ifdef OPTION
OPTION(nullptr, "opts", grp_bundle, Group, INVALID, INVALID, nullptr, 0, 0,
       "BUNDLE EXECUTABLE OPTIONS", nullptr, nullptr)
OPTION(nullptr, "opts", grp_dylib, Group, INVALID, INVALID, nullptr, 0, 0,
       "DYLIB EXECUTABLE OPTIONS", nullptr, nullptr)
OPTION(nullptr, "outs", grp_kind, Group, INVALID, INVALID, nullptr, 0, 0,
       "OUTPUT KIND", nullptr, nullptr)
OPTION(nullptr, "libs", grp_libs, Group, INVALID, INVALID, nullptr, 0, 0,
       "LIBRARY OPTIONS", nullptr, nullptr)
OPTION(nullptr, "opts", grp_main, Group, INVALID, INVALID, nullptr, 0, 0,
       "MAIN EXECUTABLE OPTIONS", nullptr, nullptr)
OPTION(nullptr, "obsolete", grp_obsolete, Group, INVALID, INVALID, nullptr, 0, 0,
       "OBSOLETE OPTIONS", nullptr, nullptr)
OPTION(nullptr, "opts", grp_opts, Group, INVALID, INVALID, nullptr, 0, 0,
       "OPTIMIZATIONS", nullptr, nullptr)

//////////
// Options

OPTION(prefix_0, "<input>", INPUT, Input, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_0, "<unknown>", UNKNOWN, Unknown, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "all_load", all_load, Flag, grp_libs, INVALID, nullptr, 0, 0,
       "Forces all members of all static libraries to be loaded", nullptr, nullptr)
OPTION(prefix_1, "arch", arch, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Architecture to link", "<arch-name>", nullptr)
OPTION(prefix_1, "bundle_loader", bundle_loader, Separate, grp_bundle, INVALID, nullptr, 0, 0,
       "The executable that will be loading this Mach-O bundle", "<path>", nullptr)
OPTION(prefix_1, "bundle", bundle, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create dynamic bundle", nullptr, nullptr)
OPTION(prefix_1, "compatibility_version", compatibility_version, Separate, grp_dylib, INVALID, nullptr, 0, 0,
       "The dylib's compatibility version", "<version>", nullptr)
OPTION(prefix_1, "current_version", current_version, Separate, grp_dylib, INVALID, nullptr, 0, 0,
       "The dylib's current version", "<version>", nullptr)
OPTION(prefix_1, "data_in_code_info", data_in_code_info, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Force generation of a data in code load command", nullptr, nullptr)
OPTION(prefix_1, "dead_strip", dead_strip, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Remove unreference code and data", nullptr, nullptr)
OPTION(prefix_1, "demangle", demangle, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Demangles symbol names in errors and warnings", nullptr, nullptr)
OPTION(prefix_1, "dependency_info", dependency_info, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Write binary list of files used during link", "<file>", nullptr)
OPTION(prefix_1, "dylib_compatibility_version", dylib_compatibility_version, Separate, INVALID, compatibility_version, nullptr, 0, 0, nullptr, "<version>", nullptr)
OPTION(prefix_1, "dylib_current_version", dylib_current_version, Separate, INVALID, current_version, nullptr, 0, 0, nullptr, "<version>", nullptr)
OPTION(prefix_1, "dylib_install_name", dylib_install_name, Separate, INVALID, install_name, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "dylib", dylib, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create dynamic library", nullptr, nullptr)
OPTION(prefix_1, "dynamic", dynamic, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create dynamic executable (default)", nullptr, nullptr)
OPTION(prefix_2, "error-limit", error_limit, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", "<number>", nullptr)
OPTION(prefix_1, "execute", execute, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create main executable (default)", nullptr, nullptr)
OPTION(prefix_1, "export_dynamic", export_dynamic, Flag, grp_main, INVALID, nullptr, 0, 0,
       "Preserves all global symbols in main executables during LTO", nullptr, nullptr)
OPTION(prefix_1, "exported_symbols_list", exported_symbols_list, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Restricts which symbols will be exported", "<file-path>", nullptr)
OPTION(prefix_1, "exported_symbol", exported_symbol, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Restricts which symbols will be exported", "<symbol>", nullptr)
OPTION(prefix_1, "e", entry, Separate, grp_main, INVALID, nullptr, 0, 0,
       "entry symbol name", "<entry-name>", nullptr)
OPTION(prefix_1, "filelist", filelist, Separate, INVALID, INVALID, nullptr, 0, 0,
       "file containing paths to input files", "<path>", nullptr)
OPTION(prefix_1, "flat_namespace", flat_namespace, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Resolves symbols in any (transitively) linked dynamic libraries. Source libraries are not recorded: dyld will re-search all images at runtime and use the first definition found.", nullptr, nullptr)
OPTION(prefix_1, "force_load", force_load, Separate, grp_libs, INVALID, nullptr, 0, 0,
       "Forces all members of specified static libraries to be loaded", "<library-path>", nullptr)
OPTION(prefix_1, "framework", framework, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Base name of framework searched for in -F directories", "<name>", nullptr)
OPTION(prefix_1, "function_starts", function_starts, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Force generation of a function starts load command", nullptr, nullptr)
OPTION(prefix_1, "F", F, JoinedOrSeparate, grp_libs, INVALID, nullptr, 0, 0,
       "Add directory to framework search path", "<dir>", nullptr)
OPTION(prefix_1, "image_base", image_base, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "install_name", install_name, Separate, grp_dylib, INVALID, nullptr, 0, 0,
       "The dylib's install name", "<path>", nullptr)
OPTION(prefix_1, "ios_simulator_version_min", ios_simulator_version_min, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Minimum iOS simulator version", "<version>", nullptr)
OPTION(prefix_1, "ios_version_min", ios_version_min, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Minimum iOS version", "<version>", nullptr)
OPTION(prefix_1, "iphoneos_version_min", iphoneos_version_min, Separate, INVALID, ios_version_min, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "keep_private_externs", keep_private_externs, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Private extern (hidden) symbols should not be transformed into local symbols", nullptr, nullptr)
OPTION(prefix_1, "lto_library", lto_library, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Ignored for compatibility with other linkers", "<path>", nullptr)
OPTION(prefix_1, "L", L, JoinedOrSeparate, grp_libs, INVALID, nullptr, 0, 0,
       "Add directory to library search path", "<dir>", nullptr)
OPTION(prefix_1, "l", l, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Base name of library searched for in -L directories", "<libname>", nullptr)
OPTION(prefix_1, "macosx_version_min", macosx_version_min, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Minimum Mac OS X version", "<version>", nullptr)
OPTION(prefix_1, "mark_dead_strippable_dylib", mark_dead_strippable_dylib, Flag, grp_dylib, INVALID, nullptr, 0, 0,
       "Marks the dylib as having no side effects during initialization", nullptr, nullptr)
OPTION(prefix_1, "mllvm", mllvm, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Options to pass to LLVM during LTO", "<option>", nullptr)
OPTION(prefix_1, "multi_module", multi_module, Flag, grp_obsolete, INVALID, nullptr, 0, 0,
       "Unsupported way to build dylibs", nullptr, nullptr)
OPTION(prefix_1, "no_data_in_code_info", no_data_in_code_info, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Disable generation of a data in code load command", nullptr, nullptr)
OPTION(prefix_1, "no_function_starts", no_function_starts, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Disable generation of a function starts load command", nullptr, nullptr)
OPTION(prefix_1, "no_objc_category_merging", no_objc_category_merging, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Disables the optimisation which merges Objective-C categories on a class in to the class itself.", nullptr, nullptr)
OPTION(prefix_1, "no_pie", no_pie, Flag, grp_main, INVALID, nullptr, 0, 0,
       "Do not create Position Independent Executable", nullptr, nullptr)
OPTION(prefix_1, "no_version_load_command", no_version_load_command, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Disable generation of a version load command", nullptr, nullptr)
OPTION(prefix_1, "objc_gc_compaction", objc_gc_compaction, Flag, grp_obsolete, INVALID, nullptr, 0, 0,
       "Unsupported ObjC GC option", nullptr, nullptr)
OPTION(prefix_1, "objc_gc_only", objc_gc_only, Flag, grp_obsolete, INVALID, nullptr, 0, 0,
       "Unsupported ObjC GC option", nullptr, nullptr)
OPTION(prefix_1, "objc_gc", objc_gc, Flag, grp_obsolete, INVALID, nullptr, 0, 0,
       "Unsupported ObjC GC option", nullptr, nullptr)
OPTION(prefix_1, "order_file", order_file, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "re-order and move specified symbols to start of their section", "<file-path>", nullptr)
OPTION(prefix_1, "o", output, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Output file path", "<path>", nullptr)
OPTION(prefix_1, "path_exists", path_exists, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Used with -test_file_usage to declare a path", "<path>", nullptr)
OPTION(prefix_1, "pie", pie, Flag, grp_main, INVALID, nullptr, 0, 0,
       "Create Position Independent Executable (for ASLR)", nullptr, nullptr)
OPTION(prefix_1, "preload", preload, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create binary for use with embedded systems", nullptr, nullptr)
OPTION(prefix_1, "print_atoms", print_atoms, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Emit output as yaml atoms", nullptr, nullptr)
OPTION(prefix_1, "rpath", rpath, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Add path to the runpath search path list for image being created", "<path>", nullptr)
OPTION(prefix_1, "r", relocatable, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create relocatable object file", nullptr, nullptr)
OPTION(prefix_1, "sdk_version", sdk_version, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "SDK version", "<version>", nullptr)
OPTION(prefix_1, "sectalign", sectalign, MultiArg, INVALID, INVALID, nullptr, 0, 3,
       "Alignment for segment/section", "<segname> <sectname> <alignment>", nullptr)
OPTION(prefix_1, "sectcreate", sectcreate, MultiArg, INVALID, INVALID, nullptr, 0, 3,
       "Create section <segname>/<sectname> from contents of <file>", "<segname> <sectname> <file>", nullptr)
OPTION(prefix_1, "seg1addr", seg1addr, Separate, INVALID, image_base, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "single_module", single_module, Flag, grp_obsolete, INVALID, nullptr, 0, 0,
       "Default for dylibs", nullptr, nullptr)
OPTION(prefix_1, "source_version", source_version, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Source version", "<version>", nullptr)
OPTION(prefix_1, "stack_size", stack_size, Separate, grp_main, INVALID, nullptr, 0, 0,
       "Specifies the maximum stack size for the main thread in a program. Must be a page-size multiple. (default=8Mb)", nullptr, nullptr)
OPTION(prefix_1, "static", static, Flag, grp_kind, INVALID, nullptr, 0, 0,
       "Create static executable", nullptr, nullptr)
OPTION(prefix_1, "syslibroot", syslibroot, Separate, grp_libs, INVALID, nullptr, 0, 0,
       "Add path to SDK to all absolute library search paths", "<dir>", nullptr)
OPTION(prefix_1, "S", S, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Remove debug information (STABS or DWARF) from the output file", nullptr, nullptr)
OPTION(prefix_1, "test_file_usage", test_file_usage, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Only files specified by -file_exists are considered to exist. Print which files would be used", nullptr, nullptr)
OPTION(prefix_1, "twolevel_namespace", twolevel_namespace, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Resolves symbols in listed libraries only. Source libraries are recorded in the symbol table.", nullptr, nullptr)
OPTION(prefix_1, "t", t, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print the names of the input files as ld processes them", nullptr, nullptr)
OPTION(prefix_1, "undefined", undefined, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Determines how undefined symbols are handled.", "<undefined>", nullptr)
OPTION(prefix_1, "unexported_symbols_list", unexported_symbols_list, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "Lists symbols that should not be exported", "<file-path>", nullptr)
OPTION(prefix_1, "unexported_symbol", unexported_symbol, Separate, grp_opts, INVALID, nullptr, 0, 0,
       "A symbol which should not be exported", "<symbol>", nullptr)
OPTION(prefix_1, "upward-l", upward_l, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Base name of upward library searched for in -L directories", "<libname>", nullptr)
OPTION(prefix_1, "upward_framework", upward_framework, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Base name of upward framework searched for in -F directories", "<name>", nullptr)
OPTION(prefix_1, "upward_library", upward_library, Separate, INVALID, INVALID, nullptr, 0, 0,
       "path to upward dylib to link with", "<path>", nullptr)
OPTION(prefix_1, "version_load_command", version_load_command, Flag, grp_opts, INVALID, nullptr, 0, 0,
       "Force generation of a version load command", nullptr, nullptr)
OPTION(prefix_1, "v", v, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print linker information", nullptr, nullptr)
OPTION(prefix_1, "Z", Z, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not search standard directories for libraries or frameworks", nullptr, nullptr)
#endif // OPTION

#ifdef OPTTABLE_ARG_INIT
//////////
// Option Values


#endif // OPTTABLE_ARG_INIT
