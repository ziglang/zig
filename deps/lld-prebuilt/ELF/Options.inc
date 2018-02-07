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
OPTION(prefix_1, "(", start_group_paren, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, ")", end_group_paren, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "allow-multiple-definition", allow_multiple_definition, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Allow multiple definitions", nullptr, nullptr)
OPTION(prefix_2, "allow-shlib-undefined", allow_shlib_undefined, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "as-needed", as_needed, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Only set DT_NEEDED for shared libraries if used", nullptr, nullptr)
OPTION(prefix_2, "auxiliary", auxiliary, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set DT_AUXILIARY field to the specified name", nullptr, nullptr)
OPTION(prefix_2, "Bdynamic", Bdynamic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Link against shared libraries", nullptr, nullptr)
OPTION(prefix_2, "Bshareable", alias_shared_Bshareable, Flag, INVALID, shared, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Bstatic", Bstatic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not link against shared libraries", nullptr, nullptr)
OPTION(prefix_2, "Bsymbolic-functions", Bsymbolic_functions, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Bind defined function symbols locally", nullptr, nullptr)
OPTION(prefix_2, "Bsymbolic", Bsymbolic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Bind defined symbols locally", nullptr, nullptr)
OPTION(prefix_2, "build-id=", build_id_eq, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Generate build ID note", nullptr, nullptr)
OPTION(prefix_2, "build-id", build_id, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Generate build ID note", nullptr, nullptr)
OPTION(prefix_2, "b", alias_format_b, Separate, INVALID, format, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "call_shared", alias_Bdynamic_call_shared, Flag, INVALID, Bdynamic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "chroot", chroot, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "color-diagnostics=", color_diagnostics_eq, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_2, "color-diagnostics", color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_2, "compress-debug-sections=", compress_debug_sections_eq, Joined, INVALID, compress_debug_sections, nullptr, 0, 0,
       "Compress DWARF debug sections", nullptr, nullptr)
OPTION(prefix_2, "compress-debug-sections", compress_debug_sections, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Compress DWARF debug sections", nullptr, nullptr)
OPTION(prefix_2, "cref", cref, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "dc", alias_define_common_dc, Flag, INVALID, define_common, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "define-common", define_common, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Assign space to common symbols", nullptr, nullptr)
OPTION(prefix_2, "defsym=", defsym_eq, Joined, INVALID, defsym, nullptr, 0, 0,
       "Define a symbol alias", nullptr, nullptr)
OPTION(prefix_2, "defsym", defsym, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Define a symbol alias", nullptr, nullptr)
OPTION(prefix_2, "demangle", demangle, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Demangle symbol names", nullptr, nullptr)
OPTION(prefix_2, "detect-odr-violations", detect_odr_violations, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "disable-new-dtags", disable_new_dtags, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable new dynamic tags", nullptr, nullptr)
OPTION(prefix_2, "disable-verify", disable_verify, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "discard-all", discard_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Delete all local symbols", nullptr, nullptr)
OPTION(prefix_2, "discard-locals", discard_locals, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Delete temporary local symbols", nullptr, nullptr)
OPTION(prefix_2, "discard-none", discard_none, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Keep all symbols in the symbol table", nullptr, nullptr)
OPTION(prefix_2, "dn", alias_Bstatic_dn, Flag, INVALID, Bstatic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "dp", alias_define_common_dp, Flag, INVALID, define_common, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "dynamic-linker", dynamic_linker, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Which dynamic linker to use", nullptr, nullptr)
OPTION(prefix_2, "dynamic-list=", dynamic_list_eq, Joined, INVALID, dynamic_list, nullptr, 0, 0,
       "Read a list of dynamic symbols", nullptr, nullptr)
OPTION(prefix_2, "dynamic-list", dynamic_list, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Read a list of dynamic symbols", nullptr, nullptr)
OPTION(prefix_2, "dy", alias_Bdynamic_dy, Flag, INVALID, Bdynamic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "d", alias_define_common_d, Flag, INVALID, define_common, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "EB", EB, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "eh-frame-hdr", eh_frame_hdr, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Request creation of .eh_frame_hdr section and PT_GNU_EH_FRAME segment header", nullptr, nullptr)
OPTION(prefix_2, "EL", EL, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "emit-relocs", emit_relocs, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Generate relocations in output", nullptr, nullptr)
OPTION(prefix_2, "enable-new-dtags", enable_new_dtags, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable new dynamic tags", nullptr, nullptr)
OPTION(prefix_2, "end-group", end_group, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "end-lib", end_lib, Flag, INVALID, INVALID, nullptr, 0, 0,
       "End a grouping of objects that should be treated as if they were together in an archive", nullptr, nullptr)
OPTION(prefix_2, "entry=", entry_eq, Joined, INVALID, entry, nullptr, 0, 0,
       "Name of entry point symbol", "<entry>", nullptr)
OPTION(prefix_2, "entry", entry, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Name of entry point symbol", "<entry>", nullptr)
OPTION(prefix_2, "error-limit=", error_limit_eq, Joined, INVALID, error_limit, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", nullptr, nullptr)
OPTION(prefix_2, "error-limit", error_limit, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", nullptr, nullptr)
OPTION(prefix_2, "error-unresolved-symbols", error_unresolved_symbols, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Report unresolved symbols as errors", nullptr, nullptr)
OPTION(prefix_2, "exclude-libs=", exclude_libs_eq, Joined, INVALID, exclude_libs, nullptr, 0, 0,
       "Exclude static libraries from automatic export", nullptr, nullptr)
OPTION(prefix_2, "exclude-libs", exclude_libs, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Exclude static libraries from automatic export", nullptr, nullptr)
OPTION(prefix_2, "export-dynamic-symbol=", export_dynamic_symbol_eq, Joined, INVALID, export_dynamic_symbol, nullptr, 0, 0,
       "Put a symbol in the dynamic symbol table", nullptr, nullptr)
OPTION(prefix_2, "export-dynamic-symbol", export_dynamic_symbol, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Put a symbol in the dynamic symbol table", nullptr, nullptr)
OPTION(prefix_2, "export-dynamic", export_dynamic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Put symbols in the dynamic symbol table", nullptr, nullptr)
OPTION(prefix_1, "E", alias_export_dynamic_E, Flag, INVALID, export_dynamic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "e", alias_entry_e, JoinedOrSeparate, INVALID, entry, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "fatal-warnings", fatal_warnings, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Treat warnings as errors", nullptr, nullptr)
OPTION(prefix_2, "filter=", filter_eq, Joined, INVALID, filter, nullptr, 0, 0,
       "Set DT_FILTER field to the specified name", nullptr, nullptr)
OPTION(prefix_2, "filter", filter, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set DT_FILTER field to the specified name", nullptr, nullptr)
OPTION(prefix_2, "fini=", fini_eq, Joined, INVALID, fini, nullptr, 0, 0,
       "Specify a finalizer function", "<symbol>", nullptr)
OPTION(prefix_2, "fini", fini, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify a finalizer function", "<symbol>", nullptr)
OPTION(prefix_2, "fix-cortex-a53-843419", fix_cortex_a53_843419, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Apply fixes for AArch64 Cortex-A53 erratum 843419", nullptr, nullptr)
OPTION(prefix_2, "format=", format_eq, Joined, INVALID, format, nullptr, 0, 0,
       "Change the input format of the inputs following this option", "<input-format>", nullptr)
OPTION(prefix_2, "format", format, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Change the input format of the inputs following this option", "<input-format>", nullptr)
OPTION(prefix_2, "full-shutdown", full_shutdown, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Perform a full shutdown instead of calling _exit", nullptr, nullptr)
OPTION(prefix_1, "F", alias_filter, Separate, INVALID, filter, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "f", alias_auxiliary, Separate, INVALID, auxiliary, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "gc-sections", gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable garbage collection of unused sections", nullptr, nullptr)
OPTION(prefix_2, "gdb-index", gdb_index, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Generate .gdb_index section", nullptr, nullptr)
OPTION(prefix_1, "G", G, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "g", g, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "hash-style=", hash_style_eq, Joined, INVALID, hash_style, nullptr, 0, 0,
       "Specify hash style (sysv, gnu or both)", nullptr, nullptr)
OPTION(prefix_2, "hash-style", hash_style, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify hash style (sysv, gnu or both)", nullptr, nullptr)
OPTION(prefix_2, "help", help, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print option help", nullptr, nullptr)
OPTION(prefix_1, "h", alias_soname_h, JoinedOrSeparate, INVALID, soname, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "icf-data", icf_data, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable ICF to also fold identical read only data", nullptr, nullptr)
OPTION(prefix_2, "icf=all", icf_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable identical code folding", nullptr, nullptr)
OPTION(prefix_2, "icf=none", icf_none, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable identical code folding", nullptr, nullptr)
OPTION(prefix_2, "image-base=", image_base_eq, Joined, INVALID, image_base, nullptr, 0, 0,
       "Set the base address", nullptr, nullptr)
OPTION(prefix_2, "image-base", image_base, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set the base address", nullptr, nullptr)
OPTION(prefix_2, "init=", init_eq, Joined, INVALID, init, nullptr, 0, 0,
       "Specify an initializer function", "<symbol>", nullptr)
OPTION(prefix_2, "init", init, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify an initializer function", "<symbol>", nullptr)
OPTION(prefix_2, "library-path=", library_path_eq, Joined, INVALID, library_path, nullptr, 0, 0,
       "Add a directory to the library search path", "<dir>", nullptr)
OPTION(prefix_2, "library-path", library_path, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Add a directory to the library search path", "<dir>", nullptr)
OPTION(prefix_2, "library=", library_eq, Joined, INVALID, library, nullptr, 0, 0,
       "Root name of library to use", "<libName>", nullptr)
OPTION(prefix_2, "library", library, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Root name of library to use", "<libName>", nullptr)
OPTION(prefix_2, "long-plt", long_plt, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "lto-aa-pipeline=", lto_aa_pipeline, Joined, INVALID, INVALID, nullptr, 0, 0,
       "AA pipeline to run during LTO. Used in conjunction with -lto-newpm-passes", nullptr, nullptr)
OPTION(prefix_2, "lto-newpm-passes=", lto_newpm_passes, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Passes to run during LTO", nullptr, nullptr)
OPTION(prefix_2, "lto-O", lto_O, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Optimization level for LTO", "<opt-level>", nullptr)
OPTION(prefix_2, "lto-partitions=", lto_partitions, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Number of LTO codegen partitions", nullptr, nullptr)
OPTION(prefix_1, "L", alias_library_path, JoinedOrSeparate, INVALID, library_path, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "l", alias_library, JoinedOrSeparate, INVALID, library, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Map=", Map_eq, Joined, INVALID, Map, nullptr, 0, 0,
       "Print a link map to the specified file", nullptr, nullptr)
OPTION(prefix_2, "Map", Map, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Print a link map to the specified file", nullptr, nullptr)
OPTION(prefix_2, "merge-exidx-entries", merge_exidx_entries, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable merging .ARM.exidx entries", nullptr, nullptr)
OPTION(prefix_2, "mllvm", mllvm, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "M", alias_print_map_M, Flag, INVALID, print_map, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "m", m, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Set target emulation", nullptr, nullptr)
OPTION(prefix_2, "no-add-needed", no_add_needed, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-allow-shlib-undefined", no_allow_shlib_undefined, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-as-needed", no_as_needed, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Always DT_NEEDED for shared libraries", nullptr, nullptr)
OPTION(prefix_2, "no-color-diagnostics", no_color_diagnostics, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not use colors in diagnostics", nullptr, nullptr)
OPTION(prefix_2, "no-copy-dt-needed-entries", no_copy_dt_needed_entries, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-ctors-in-init-array", no_ctors_in_init_array, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-define-common", no_define_common, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not assign space to common symbols", nullptr, nullptr)
OPTION(prefix_2, "no-demangle", no_demangle, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not demangle symbol names", nullptr, nullptr)
OPTION(prefix_2, "no-dynamic-linker", no_dynamic_linker, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Inhibit output of .interp section", nullptr, nullptr)
OPTION(prefix_2, "no-eh-frame-hdr", no_eh_frame_hdr, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not create .eh_frame_hdr section", nullptr, nullptr)
OPTION(prefix_2, "no-export-dynamic", no_export_dynamic, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-fatal-warnings", no_fatal_warnings, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-gc-sections", no_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable garbage collection of unused sections", nullptr, nullptr)
OPTION(prefix_2, "no-gdb-index", no_gdb_index, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not generate .gdb_index section", nullptr, nullptr)
OPTION(prefix_2, "no-gnu-unique", no_gnu_unique, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable STB_GNU_UNIQUE symbol binding", nullptr, nullptr)
OPTION(prefix_2, "no-keep-memory", no_keep_memory, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-merge-exidx-entries", no_merge_exidx_entries, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable merging .ARM.exidx entries", nullptr, nullptr)
OPTION(prefix_2, "no-mmap-output-file", no_mmap_output_file, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "no-omagic", no_omagic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not set the text data sections to be writable", "<magic>", nullptr)
OPTION(prefix_2, "no-pie", no_pie, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not create a position independent executable", nullptr, nullptr)
OPTION(prefix_2, "no-print-gc-sections", no_print_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not list removed unused sections", nullptr, nullptr)
OPTION(prefix_2, "no-rosegment", no_rosegment, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not put read-only non-executable sections in their own segment", nullptr, nullptr)
OPTION(prefix_2, "no-threads", no_threads, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Do not run the linker multi-threaded", nullptr, nullptr)
OPTION(prefix_2, "no-undefined-version", no_undefined_version, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Report version scripts that refer undefined symbols", nullptr, nullptr)
OPTION(prefix_2, "no-undefined", no_undefined, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Report unresolved symbols even if the linker is creating a shared library", nullptr, nullptr)
OPTION(prefix_2, "no-warn-common", no_warn_common, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-warn-mismatch", no_warn_mismatch, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "no-whole-archive", no_whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Restores the default behavior of loading archive members", nullptr, nullptr)
OPTION(prefix_2, "noinhibit-exec", noinhibit_exec, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Retain the executable output file whenever it is still usable", nullptr, nullptr)
OPTION(prefix_2, "non_shared", alias_Bstatic_non_shared, Flag, INVALID, Bstatic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "nostdlib", nostdlib, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Only search directories specified on the command line", nullptr, nullptr)
OPTION(prefix_1, "N", alias_omagic, Flag, INVALID, omagic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "oformat", oformat, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specify the binary format for the output object file", "<format>", nullptr)
OPTION(prefix_3, "omagic", omagic, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Set the text and data sections to be readable and writable", "<magic>", nullptr)
OPTION(prefix_3, "opt-remarks-filename", opt_remarks_filename, Separate, INVALID, INVALID, nullptr, 0, 0,
       "YAML output file for optimization remarks", nullptr, nullptr)
OPTION(prefix_3, "opt-remarks-with-hotness", opt_remarks_with_hotness, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Include hotness informations in the optimization remarks file", nullptr, nullptr)
OPTION(prefix_2, "orphan-handling=", orphan_handling_eq, Joined, INVALID, orphan_handling, nullptr, 0, 0,
       "Control how orphan sections are handled when linker script used", nullptr, nullptr)
OPTION(prefix_2, "orphan-handling", orphan_handling, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Control how orphan sections are handled when linker script used", nullptr, nullptr)
OPTION(prefix_3, "output=", alias_o_output, Joined, INVALID, o, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "output", alias_o_output2, Separate, INVALID, o, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "O", O, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Optimize output file size", nullptr, nullptr)
OPTION(prefix_1, "o", o, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Path to file to write output", "<path>", nullptr)
OPTION(prefix_2, "pack-dyn-relocs=", pack_dyn_relocs_eq, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Pack dynamic relocations in the given format (none or android)", "<format>", nullptr)
OPTION(prefix_2, "pic-executable", alias_pie_pic_executable, Flag, INVALID, pie, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "pie", pie, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create a position independent executable", nullptr, nullptr)
OPTION(prefix_2, "plugin-opt=", plugin_opt_eq, Joined, INVALID, plugin_opt, nullptr, 0, 0,
       "specifies LTO options for compatibility with GNU linkers", nullptr, nullptr)
OPTION(prefix_2, "plugin-opt", plugin_opt, Separate, INVALID, INVALID, nullptr, 0, 0,
       "specifies LTO options for compatibility with GNU linkers", nullptr, nullptr)
OPTION(prefix_2, "plugin=", plugin_eq, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "plugin", plugin, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "print-gc-sections", print_gc_sections, Flag, INVALID, INVALID, nullptr, 0, 0,
       "List removed unused sections", nullptr, nullptr)
OPTION(prefix_2, "print-map", print_map, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print a link map to the standard output", nullptr, nullptr)
OPTION(prefix_2, "Qy", Qy, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "q", alias_emit_relocs, Flag, INVALID, emit_relocs, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "relocatable", relocatable, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create relocatable object file", nullptr, nullptr)
OPTION(prefix_2, "reproduce=", reproduce_eq, Joined, INVALID, reproduce, nullptr, 0, 0,
       "Dump linker invocation and input files for debugging", nullptr, nullptr)
OPTION(prefix_2, "reproduce", reproduce, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Dump linker invocation and input files for debugging", nullptr, nullptr)
OPTION(prefix_2, "retain-symbols-file=", retain_symbols_file_eq, Joined, INVALID, retain_symbols_file, nullptr, 0, 0,
       "Retain only the symbols listed in the file", "<file>", nullptr)
OPTION(prefix_2, "retain-symbols-file", retain_symbols_file, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Retain only the symbols listed in the file", "<file>", nullptr)
OPTION(prefix_2, "rpath-link=", rpath_link_eq, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "rpath-link", rpath_link, Separate, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "rpath=", rpath_eq, Joined, INVALID, rpath, nullptr, 0, 0,
       "Add a DT_RUNPATH to the output", nullptr, nullptr)
OPTION(prefix_2, "rpath", rpath, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Add a DT_RUNPATH to the output", nullptr, nullptr)
OPTION(prefix_2, "rsp-quoting=", rsp_quoting_eq, Joined, INVALID, rsp_quoting, nullptr, 0, 0,
       "Quoting style for response files. Values supported: windows|posix", nullptr, nullptr)
OPTION(prefix_2, "rsp-quoting", rsp_quoting, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Quoting style for response files. Values supported: windows|posix", nullptr, nullptr)
OPTION(prefix_1, "R", alias_rpath_R, JoinedOrSeparate, INVALID, rpath, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "r", alias_relocatable_r, Flag, INVALID, relocatable, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "save-temps", save_temps, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "script=", script_eq, Joined, INVALID, script, nullptr, 0, 0,
       "Read linker script", nullptr, nullptr)
OPTION(prefix_2, "script", script, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Read linker script", nullptr, nullptr)
OPTION(prefix_2, "section-start", section_start, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set address of section", "<address>", nullptr)
OPTION(prefix_2, "shared", shared, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Build a shared object", nullptr, nullptr)
OPTION(prefix_2, "soname=", soname_eq, Joined, INVALID, soname, nullptr, 0, 0,
       "Set DT_SONAME", nullptr, nullptr)
OPTION(prefix_2, "soname", soname, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set DT_SONAME", nullptr, nullptr)
OPTION(prefix_2, "sort-common", sort_common, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "sort-section=", sort_section_eq, Joined, INVALID, sort_section, nullptr, 0, 0,
       "Specifies sections sorting rule when linkerscript is used", nullptr, nullptr)
OPTION(prefix_2, "sort-section", sort_section, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Specifies sections sorting rule when linkerscript is used", nullptr, nullptr)
OPTION(prefix_2, "start-group", start_group, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "start-lib", start_lib, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Start a grouping of objects that should be treated as if they were together in an archive", nullptr, nullptr)
OPTION(prefix_2, "static", alias_Bstatic_static, Flag, INVALID, Bstatic, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "stats", stats, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "strip-all", strip_all, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip all symbols", nullptr, nullptr)
OPTION(prefix_2, "strip-debug", strip_debug, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Strip debugging information", nullptr, nullptr)
OPTION(prefix_2, "symbol-ordering-file", symbol_ordering_file, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Layout sections in the order specified by symbol file", nullptr, nullptr)
OPTION(prefix_2, "sysroot=", sysroot_eq, Joined, INVALID, sysroot, nullptr, 0, 0,
       "Set the system root", nullptr, nullptr)
OPTION(prefix_2, "sysroot", sysroot, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Set the system root", nullptr, nullptr)
OPTION(prefix_1, "S", alias_strip_debug_S, Flag, INVALID, strip_debug, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "s", alias_strip_all, Flag, INVALID, strip_all, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "target1-abs", target1_abs, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Interpret R_ARM_TARGET1 as R_ARM_ABS32", nullptr, nullptr)
OPTION(prefix_2, "target1-rel", target1_rel, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Interpret R_ARM_TARGET1 as R_ARM_REL32", nullptr, nullptr)
OPTION(prefix_2, "target2=", target2_eq, Joined, INVALID, target2, nullptr, 0, 0,
       "Interpret R_ARM_TARGET2 as <type>, where <type> is one of rel, abs, or got-rel", "<type>", nullptr)
OPTION(prefix_2, "target2", target2, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Interpret R_ARM_TARGET2 as <type>, where <type> is one of rel, abs, or got-rel", "<type>", nullptr)
OPTION(prefix_2, "Tbss=", Tbss_eq, Joined, INVALID, Tbss, nullptr, 0, 0,
       "Same as --section-start with .bss as the sectionname", nullptr, nullptr)
OPTION(prefix_2, "Tbss", Tbss, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Same as --section-start with .bss as the sectionname", nullptr, nullptr)
OPTION(prefix_2, "Tdata=", Tdata_eq, Joined, INVALID, Tdata, nullptr, 0, 0,
       "Same as --section-start with .data as the sectionname", nullptr, nullptr)
OPTION(prefix_2, "Tdata", Tdata, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Same as --section-start with .data as the sectionname", nullptr, nullptr)
OPTION(prefix_2, "thinlto-cache-dir=", thinlto_cache_dir, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Path to ThinLTO cached object file directory", nullptr, nullptr)
OPTION(prefix_2, "thinlto-cache-policy", thinlto_cache_policy, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Pruning policy for the ThinLTO cache", nullptr, nullptr)
OPTION(prefix_2, "thinlto-jobs=", thinlto_jobs, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Number of ThinLTO jobs", nullptr, nullptr)
OPTION(prefix_2, "threads", threads, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Run the linker multi-threaded", nullptr, nullptr)
OPTION(prefix_2, "trace-symbol=", trace_symbol_eq, Joined, INVALID, trace_symbol, nullptr, 0, 0,
       "Trace references to symbols", nullptr, nullptr)
OPTION(prefix_2, "trace-symbol", trace_symbol, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Trace references to symbols", nullptr, nullptr)
OPTION(prefix_2, "trace", trace, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Print the names of the input files", nullptr, nullptr)
OPTION(prefix_2, "Ttext-segment=", alias_Ttext_segment_eq, Joined, INVALID, Ttext, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Ttext-segment", alias_Ttext_segment, Separate, INVALID, Ttext, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "Ttext=", Ttext_eq, Joined, INVALID, Ttext, nullptr, 0, 0,
       "Same as --section-start with .text as the sectionname", nullptr, nullptr)
OPTION(prefix_2, "Ttext", Ttext, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Same as --section-start with .text as the sectionname", nullptr, nullptr)
OPTION(prefix_1, "T", alias_script_T, JoinedOrSeparate, INVALID, script, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "t", alias_trace, Flag, INVALID, trace, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "undefined=", undefined_eq, Joined, INVALID, undefined, nullptr, 0, 0,
       "Force undefined symbol during linking", nullptr, nullptr)
OPTION(prefix_2, "undefined", undefined, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Force undefined symbol during linking", nullptr, nullptr)
OPTION(prefix_2, "unresolved-symbols=", unresolved_symbols_eq, Joined, INVALID, unresolved_symbols, nullptr, 0, 0,
       "Determine how to handle unresolved symbols", nullptr, nullptr)
OPTION(prefix_2, "unresolved-symbols", unresolved_symbols, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Determine how to handle unresolved symbols", nullptr, nullptr)
OPTION(prefix_1, "u", alias_undefined_u, JoinedOrSeparate, INVALID, undefined, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "verbose", verbose, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Verbose mode", nullptr, nullptr)
OPTION(prefix_2, "version-script=", version_script_eq, Joined, INVALID, version_script, nullptr, 0, 0,
       "Read a version script", nullptr, nullptr)
OPTION(prefix_2, "version-script", version_script, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Read a version script", nullptr, nullptr)
OPTION(prefix_2, "version", version, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number and exit", nullptr, nullptr)
OPTION(prefix_1, "V", alias_version_V, Flag, INVALID, version, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "v", v, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Display the version number", nullptr, nullptr)
OPTION(prefix_2, "warn-common", warn_common, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Warn about duplicate common symbols", nullptr, nullptr)
OPTION(prefix_2, "warn-execstack", warn_execstack, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "warn-once", warn_once, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "warn-shared-textrel", warn_shared_textrel, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_2, "warn-unresolved-symbols", warn_unresolved_symbols, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Report unresolved symbols as warnings", nullptr, nullptr)
OPTION(prefix_2, "whole-archive", whole_archive, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Force load of all members in a static library", nullptr, nullptr)
OPTION(prefix_2, "wrap=", wrap_eq, Joined, INVALID, wrap, nullptr, 0, 0,
       "Use wrapper functions for symbol", "<symbol>", nullptr)
OPTION(prefix_2, "wrap", wrap, Separate, INVALID, INVALID, nullptr, 0, 0,
       "Use wrapper functions for symbol", "<symbol>", nullptr)
OPTION(prefix_1, "X", alias_discard_locals_X, Flag, INVALID, discard_locals, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "x", alias_discard_all_x, Flag, INVALID, discard_all, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "y", alias_trace_symbol_y, JoinedOrSeparate, INVALID, trace_symbol, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "z", z, JoinedOrSeparate, INVALID, INVALID, nullptr, 0, 0,
       "Linker option extensions", "<option>", nullptr)
#endif // OPTION

#ifdef OPTTABLE_ARG_INIT
//////////
// Option Values


#endif // OPTTABLE_ARG_INIT
