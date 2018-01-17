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

def auxiliary: S<"auxiliary">, HelpText<"Set DT_AUXILIARY field to the specified name">;

def Bsymbolic: F<"Bsymbolic">, HelpText<"Bind defined symbols locally">;

def Bsymbolic_functions: F<"Bsymbolic-functions">,
  HelpText<"Bind defined function symbols locally">;

def Bdynamic: F<"Bdynamic">, HelpText<"Link against shared libraries">;

def Bstatic: F<"Bstatic">, HelpText<"Do not link against shared libraries">;

def build_id: F<"build-id">, HelpText<"Generate build ID note">;

def build_id_eq: J<"build-id=">, HelpText<"Generate build ID note">;

defm compress_debug_sections : Eq<"compress-debug-sections">,
  HelpText<"Compress DWARF debug sections">;

defm defsym: Eq<"defsym">, HelpText<"Define a symbol alias">;

defm library_path: Eq<"library-path">,
  HelpText<"Add a directory to the library search path">, MetaVarName<"<dir>">;

def O: JoinedOrSeparate<["-"], "O">, HelpText<"Optimize output file size">;

defm Tbss: Eq<"Tbss">,
  HelpText<"Same as --section-start with .bss as the sectionname">;

defm Tdata: Eq<"Tdata">,
  HelpText<"Same as --section-start with .data as the sectionname">;

defm Ttext: Eq<"Ttext">,
  HelpText<"Same as --section-start with .text as the sectionname">;

def allow_multiple_definition: F<"allow-multiple-definition">,
  HelpText<"Allow multiple definitions">;

def as_needed: F<"as-needed">,
  HelpText<"Only set DT_NEEDED for shared libraries if used">;

// -chroot doesn't have a help text because it is an internal option.
def chroot: S<"chroot">;

def color_diagnostics: F<"color-diagnostics">,
  HelpText<"Use colors in diagnostics">;

def color_diagnostics_eq: J<"color-diagnostics=">,
  HelpText<"Use colors in diagnostics">;

def define_common: F<"define-common">,
  HelpText<"Assign space to common symbols">;

def demangle: F<"demangle">, HelpText<"Demangle symbol names">;

def disable_new_dtags: F<"disable-new-dtags">,
  HelpText<"Disable new dynamic tags">;

def discard_all: F<"discard-all">, HelpText<"Delete all local symbols">;

def discard_locals: F<"discard-locals">,
  HelpText<"Delete temporary local symbols">;

def discard_none: F<"discard-none">,
  HelpText<"Keep all symbols in the symbol table">;

def dynamic_linker: S<"dynamic-linker">,
  HelpText<"Which dynamic linker to use">;

defm dynamic_list: Eq<"dynamic-list">,
  HelpText<"Read a list of dynamic symbols">;

def eh_frame_hdr: F<"eh-frame-hdr">,
  HelpText<"Request creation of .eh_frame_hdr section and PT_GNU_EH_FRAME segment header">;

def emit_relocs: F<"emit-relocs">, HelpText<"Generate relocations in output">;

def enable_new_dtags: F<"enable-new-dtags">,
  HelpText<"Enable new dynamic tags">;

def end_lib: F<"end-lib">,
  HelpText<"End a grouping of objects that should be treated as if they were together in an archive">;

defm entry: Eq<"entry">, HelpText<"Name of entry point symbol">,
  MetaVarName<"<entry>">;

defm error_limit: Eq<"error-limit">,
  HelpText<"Maximum number of errors to emit before stopping (0 = no limit)">;

def error_unresolved_symbols: F<"error-unresolved-symbols">,
  HelpText<"Report unresolved symbols as errors">;

defm exclude_libs: Eq<"exclude-libs">,
  HelpText<"Exclude static libraries from automatic export">;

def export_dynamic: F<"export-dynamic">,
  HelpText<"Put symbols in the dynamic symbol table">;

defm export_dynamic_symbol: Eq<"export-dynamic-symbol">,
  HelpText<"Put a symbol in the dynamic symbol table">;

def fatal_warnings: F<"fatal-warnings">,
  HelpText<"Treat warnings as errors">;

defm filter: Eq<"filter">,
  HelpText<"Set DT_FILTER field to the specified name">;

defm fini: Eq<"fini">,
  HelpText<"Specify a finalizer function">, MetaVarName<"<symbol>">;

def fix_cortex_a53_843419: F<"fix-cortex-a53-843419">,
  HelpText<"Apply fixes for AArch64 Cortex-A53 erratum 843419">;

def full_shutdown : F<"full-shutdown">,
  HelpText<"Perform a full shutdown instead of calling _exit">;

defm format: Eq<"format">,
  HelpText<"Change the input format of the inputs following this option">,
  MetaVarName<"<input-format>">;

def gc_sections: F<"gc-sections">,
  HelpText<"Enable garbage collection of unused sections">;

def gdb_index: F<"gdb-index">,
  HelpText<"Generate .gdb_index section">;

defm hash_style: Eq<"hash-style">,
  HelpText<"Specify hash style (sysv, gnu or both)">;

def help: F<"help">, HelpText<"Print option help">;

def icf_all: F<"icf=all">, HelpText<"Enable identical code folding">;

def icf_data: F<"icf-data">,
  HelpText<"Enable ICF to also fold identical read only data">;

def icf_none: F<"icf=none">, HelpText<"Disable identical code folding">;

defm image_base : Eq<"image-base">, HelpText<"Set the base address">;

defm init: Eq<"init">, HelpText<"Specify an initializer function">,
  MetaVarName<"<symbol>">;

defm library: Eq<"library">, HelpText<"Root name of library to use">,
  MetaVarName<"<libName>">;

def lto_O: J<"lto-O">, MetaVarName<"<opt-level>">,
  HelpText<"Optimization level for LTO">;

def m: JoinedOrSeparate<["-"], "m">, HelpText<"Set target emulation">;

defm Map: Eq<"Map">, HelpText<"Print a link map to the specified file">;

def merge_exidx_entries: F<"merge-exidx-entries">,
  HelpText<"Enable merging .ARM.exidx entries">;

def nostdlib: F<"nostdlib">,
  HelpText<"Only search directories specified on the command line">;

def no_as_needed: F<"no-as-needed">,
  HelpText<"Always DT_NEEDED for shared libraries">;

def no_color_diagnostics: F<"no-color-diagnostics">,
  HelpText<"Do not use colors in diagnostics">;

def no_define_common: F<"no-define-common">,
  HelpText<"Do not assign space to common symbols">;

def no_demangle: F<"no-demangle">,
  HelpText<"Do not demangle symbol names">;

def no_dynamic_linker: F<"no-dynamic-linker">,
  HelpText<"Inhibit output of .interp section">;

def no_eh_frame_hdr: F<"no-eh-frame-hdr">,
  HelpText<"Do not create .eh_frame_hdr section">;

def no_export_dynamic: F<"no-export-dynamic">;
def no_fatal_warnings: F<"no-fatal-warnings">;

def no_gc_sections: F<"no-gc-sections">,
  HelpText<"Disable garbage collection of unused sections">;

def no_gdb_index: F<"no-gdb-index">,
  HelpText<"Do not generate .gdb_index section">;

def no_gnu_unique: F<"no-gnu-unique">,
  HelpText<"Disable STB_GNU_UNIQUE symbol binding">;

def no_merge_exidx_entries: F<"no-merge-exidx-entries">,
  HelpText<"Disable merging .ARM.exidx entries">;

def no_threads: F<"no-threads">,
  HelpText<"Do not run the linker multi-threaded">;

def no_whole_archive: F<"no-whole-archive">,
  HelpText<"Restores the default behavior of loading archive members">;

def noinhibit_exec: F<"noinhibit-exec">,
  HelpText<"Retain the executable output file whenever it is still usable">;

def nopie: F<"nopie">, HelpText<"Do not create a position independent executable">;

def no_omagic: Flag<["--"], "no-omagic">, MetaVarName<"<magic>">,
  HelpText<"Do not set the text data sections to be writable">;

def no_print_gc_sections: F<"no-print-gc-sections">,
  HelpText<"Do not list removed unused sections">;

def no_rosegment: F<"no-rosegment">,
  HelpText<"Do not put read-only non-executable sections in their own segment">;

def no_undefined: F<"no-undefined">,
  HelpText<"Report unresolved symbols even if the linker is creating a shared library">;

def no_undefined_version: F<"no-undefined-version">,
  HelpText<"Report version scripts that refer undefined symbols">;

def o: JoinedOrSeparate<["-"], "o">, MetaVarName<"<path>">,
  HelpText<"Path to file to write output">;

def oformat: Separate<["--"], "oformat">, MetaVarName<"<format>">,
  HelpText<"Specify the binary format for the output object file">;

def omagic: Flag<["--"], "omagic">, MetaVarName<"<magic>">,
  HelpText<"Set the text and data sections to be readable and writable">;

defm orphan_handling: Eq<"orphan-handling">,
  HelpText<"Control how orphan sections are handled when linker script used">;

def pack_dyn_relocs_eq: J<"pack-dyn-relocs=">, MetaVarName<"<format>">,
  HelpText<"Pack dynamic relocations in the given format (none or android)">;

def pie: F<"pie">, HelpText<"Create a position independent executable">;

def print_gc_sections: F<"print-gc-sections">,
  HelpText<"List removed unused sections">;

def print_map: F<"print-map">,
  HelpText<"Print a link map to the standard output">;

defm reproduce: Eq<"reproduce">,
  HelpText<"Dump linker invocation and input files for debugging">;

defm rpath: Eq<"rpath">, HelpText<"Add a DT_RUNPATH to the output">;

def relocatable: F<"relocatable">, HelpText<"Create relocatable object file">;

defm retain_symbols_file: Eq<"retain-symbols-file">,
  HelpText<"Retain only the symbols listed in the file">,
  MetaVarName<"<file>">;

defm script: Eq<"script">, HelpText<"Read linker script">;

def section_start: S<"section-start">, MetaVarName<"<address>">,
  HelpText<"Set address of section">;

def shared: F<"shared">, HelpText<"Build a shared object">;

defm soname: Eq<"soname">, HelpText<"Set DT_SONAME">;

defm sort_section: Eq<"sort-section">,
  HelpText<"Specifies sections sorting rule when linkerscript is used">;

def start_lib: F<"start-lib">,
  HelpText<"Start a grouping of objects that should be treated as if they were together in an archive">;

def strip_all: F<"strip-all">, HelpText<"Strip all symbols">;

def strip_debug: F<"strip-debug">, HelpText<"Strip debugging information">;

def symbol_ordering_file: S<"symbol-ordering-file">,
  HelpText<"Layout sections in the order specified by symbol file">;

defm sysroot: Eq<"sysroot">, HelpText<"Set the system root">;

def target1_rel: F<"target1-rel">, HelpText<"Interpret R_ARM_TARGET1 as R_ARM_REL32">;

def target1_abs: F<"target1-abs">, HelpText<"Interpret R_ARM_TARGET1 as R_ARM_ABS32">;

defm target2: Eq<"target2">,
  HelpText<"Interpret R_ARM_TARGET2 as <type>, where <type> is one of rel, abs, or got-rel">,
  MetaVarName<"<type>">;

def threads: F<"threads">, HelpText<"Run the linker multi-threaded">;

def trace: F<"trace">, HelpText<"Print the names of the input files">;

defm trace_symbol : Eq<"trace-symbol">, HelpText<"Trace references to symbols">;

defm undefined: Eq<"undefined">,
  HelpText<"Force undefined symbol during linking">;

defm unresolved_symbols: Eq<"unresolved-symbols">,
  HelpText<"Determine how to handle unresolved symbols">;

defm rsp_quoting: Eq<"rsp-quoting">,
  HelpText<"Quoting style for response files. Values supported: windows|posix">;

def v: Flag<["-"], "v">, HelpText<"Display the version number">;

def verbose: F<"verbose">, HelpText<"Verbose mode">;

def version: F<"version">, HelpText<"Display the version number and exit">;

defm version_script: Eq<"version-script">, HelpText<"Read a version script">;

def warn_common: F<"warn-common">,
  HelpText<"Warn about duplicate common symbols">;

def warn_unresolved_symbols: F<"warn-unresolved-symbols">,
  HelpText<"Report unresolved symbols as warnings">;

def whole_archive: F<"whole-archive">,
  HelpText<"Force load of all members in a static library">;

defm wrap: Eq<"wrap">, HelpText<"Use wrapper functions for symbol">,
  MetaVarName<"<symbol>">;

def z: JoinedOrSeparate<["-"], "z">, MetaVarName<"<option>">,
  HelpText<"Linker option extensions">;

// Aliases
def alias_auxiliary: Separate<["-"], "f">, Alias<auxiliary>;
def alias_Bdynamic_call_shared: F<"call_shared">, Alias<Bdynamic>;
def alias_Bdynamic_dy: F<"dy">, Alias<Bdynamic>;
def alias_Bstatic_dn: F<"dn">, Alias<Bstatic>;
def alias_Bstatic_non_shared: F<"non_shared">, Alias<Bstatic>;
def alias_Bstatic_static: F<"static">, Alias<Bstatic>;
def alias_define_common_d: Flag<["-"], "d">, Alias<define_common>;
def alias_define_common_dc: F<"dc">, Alias<define_common>;
def alias_define_common_dp: F<"dp">, Alias<define_common>;
def alias_discard_all_x: Flag<["-"], "x">, Alias<discard_all>;
def alias_discard_locals_X: Flag<["-"], "X">, Alias<discard_locals>;
def alias_emit_relocs: Flag<["-"], "q">, Alias<emit_relocs>;
def alias_entry_e: JoinedOrSeparate<["-"], "e">, Alias<entry>;
def alias_export_dynamic_E: Flag<["-"], "E">, Alias<export_dynamic>;
def alias_filter: Separate<["-"], "F">, Alias<filter>;
def alias_format_b: S<"b">, Alias<format>;
def alias_library: JoinedOrSeparate<["-"], "l">, Alias<library>;
def alias_library_path: JoinedOrSeparate<["-"], "L">, Alias<library_path>;
def alias_omagic: Flag<["-"], "N">, Alias<omagic>;
def alias_o_output: Joined<["--"], "output=">, Alias<o>;
def alias_o_output2 : Separate<["--"], "output">, Alias<o>;
def alias_pie_pic_executable: F<"pic-executable">, Alias<pie>;
def alias_print_map_M: Flag<["-"], "M">, Alias<print_map>;
def alias_relocatable_r: Flag<["-"], "r">, Alias<relocatable>;
def alias_rpath_R: JoinedOrSeparate<["-"], "R">, Alias<rpath>;
def alias_script_T: JoinedOrSeparate<["-"], "T">, Alias<script>;
def alias_shared_Bshareable: F<"Bshareable">, Alias<shared>;
def alias_soname_h: JoinedOrSeparate<["-"], "h">, Alias<soname>;
def alias_strip_all: Flag<["-"], "s">, Alias<strip_all>;
def alias_strip_debug_S: Flag<["-"], "S">, Alias<strip_debug>;
def alias_trace: Flag<["-"], "t">, Alias<trace>;
def alias_trace_symbol_y : JoinedOrSeparate<["-"], "y">, Alias<trace_symbol>;
def alias_Ttext_segment: S<"Ttext-segment">, Alias<Ttext>;
def alias_Ttext_segment_eq: J<"Ttext-segment=">, Alias<Ttext>;
def alias_undefined_u: JoinedOrSeparate<["-"], "u">, Alias<undefined>;
def alias_version_V: Flag<["-"], "V">, Alias<version>;

// Our symbol resolution algorithm handles symbols in archive files differently
// than traditional linkers, so we don't need --start-group and --end-group.
// These options are recongized for compatibility but ignored.
def end_group: F<"end-group">;
def end_group_paren: Flag<["-"], ")">;
def start_group: F<"start-group">;
def start_group_paren: Flag<["-"], "(">;

// LTO-related options.
def lto_aa_pipeline: J<"lto-aa-pipeline=">,
  HelpText<"AA pipeline to run during LTO. Used in conjunction with -lto-newpm-passes">;
def lto_newpm_passes: J<"lto-newpm-passes=">,
  HelpText<"Passes to run during LTO">;
def lto_partitions: J<"lto-partitions=">,
  HelpText<"Number of LTO codegen partitions">;
def disable_verify: F<"disable-verify">;
def mllvm: S<"mllvm">;
def opt_remarks_filename: Separate<["--"], "opt-remarks-filename">,
  HelpText<"YAML output file for optimization remarks">;
def opt_remarks_with_hotness: Flag<["--"], "opt-remarks-with-hotness">,
  HelpText<"Include hotness informations in the optimization remarks file">;
defm plugin_opt: Eq<"plugin-opt">,
  HelpText<"specifies LTO options for compatibility with GNU linkers">;
def save_temps: F<"save-temps">;
def thinlto_cache_dir: J<"thinlto-cache-dir=">,
  HelpText<"Path to ThinLTO cached object file directory">;
def thinlto_cache_policy: S<"thinlto-cache-policy">,
  HelpText<"Pruning policy for the ThinLTO cache">;
def thinlto_jobs: J<"thinlto-jobs=">, HelpText<"Number of ThinLTO jobs">;

// Ignore LTO plugin-related options.
// clang -flto passes -plugin and -plugin-opt to the linker. This is required
// for ld.gold and ld.bfd to get LTO working. But it's not for lld which doesn't
// rely on a plugin. Instead of detecting which linker is used on clang side we
// just ignore the option on lld side as it's easier. In fact, the linker could
// be called 'ld' and understanding which linker is used would require parsing of
// --version output.
def plugin: S<"plugin">;
def plugin_eq: J<"plugin=">;

// Options listed below are silently ignored for now for compatibility.
def allow_shlib_undefined: F<"allow-shlib-undefined">;
def cref: F<"cref">;
def detect_odr_violations: F<"detect-odr-violations">;
def g: Flag<["-"], "g">;
def long_plt: F<"long-plt">;
def no_add_needed: F<"no-add-needed">;
def no_allow_shlib_undefined: F<"no-allow-shlib-undefined">;
def no_copy_dt_needed_entries: F<"no-copy-dt-needed-entries">;
def no_ctors_in_init_array: F<"no-ctors-in-init-array">;
def no_keep_memory: F<"no-keep-memory">;
def no_mmap_output_file: F<"no-mmap-output-file">;
def no_warn_common: F<"no-warn-common">;
def no_warn_mismatch: F<"no-warn-mismatch">;
def rpath_link: S<"rpath-link">;
def rpath_link_eq: J<"rpath-link=">;
def sort_common: F<"sort-common">;
def stats: F<"stats">;
def warn_execstack: F<"warn-execstack">;
def warn_once: F<"warn-once">;
def warn_shared_textrel: F<"warn-shared-textrel">;
def EB : F<"EB">;
def EL : F<"EL">;
def G: JoinedOrSeparate<["-"], "G">;
def Qy : F<"Qy">;
