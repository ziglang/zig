//! User-specified settings that have all the defaults resolved into concrete
//! values. These values are observable before calling Compilation.create for
//! the benefit of Module creation API, which needs access to these details in
//! order to resolve per-Module defaults.

have_zcu: bool,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
link_libc: bool,
link_libcpp: bool,
link_libunwind: bool,
/// True if and only if the c_source_files field will have nonzero length when
/// calling Compilation.create.
any_c_source_files: bool,
/// This is true if any Module has unwind_tables set explicitly to true. Until
/// Compilation.create is called, it is possible for this to be false while in
/// fact all Module instances have unwind_tables=true due to the default
/// being unwind_tables=true. After Compilation.create is called this will
/// also take into account the default setting, making this value true if and
/// only if any Module has unwind_tables set to true.
any_unwind_tables: bool,
/// This is true if any Module has single_threaded set explicitly to false. Until
/// Compilation.create is called, it is possible for this to be false while in
/// fact all Module instances have single_threaded=false due to the default
/// being non-single-threaded. After Compilation.create is called this will
/// also take into account the default setting, making this value true if and
/// only if any Module has single_threaded set to false.
any_non_single_threaded: bool,
/// This is true if and only if any Module has error_tracing set to true.
/// Function types and function calling convention depend on this global value,
/// however, other kinds of error tracing are omitted depending on the
/// per-Module setting.
any_error_tracing: bool,
any_sanitize_thread: bool,
pie: bool,
/// If this is true then linker code is responsible for making an LLVM IR
/// Module, outputting it to an object file, and then linking that together
/// with link options and other objects. Otherwise (depending on `use_lld`)
/// linker code directly outputs and updates the final binary.
use_llvm: bool,
/// Whether or not the LLVM library API will be used by the LLVM backend.
use_lib_llvm: bool,
/// If this is true then linker code is responsible for outputting an object
/// file and then using LLD to link it together with the link options and other
/// objects. Otherwise (depending on `use_llvm`) linker code directly outputs
/// and updates the final binary.
use_lld: bool,
c_frontend: CFrontend,
lto: bool,
/// WASI-only. Type of WASI execution model ("command" or "reactor").
/// Always set to `command` for non-WASI targets.
wasi_exec_model: std.builtin.WasiExecModel,
import_memory: bool,
export_memory: bool,
shared_memory: bool,
is_test: bool,
debug_format: DebugFormat,
root_strip: bool,
root_error_tracing: bool,
dll_export_fns: bool,
rdynamic: bool,

pub const CFrontend = enum { clang, aro };

pub const DebugFormat = union(enum) {
    strip,
    dwarf: std.dwarf.Format,
    code_view,
};

pub const Options = struct {
    output_mode: std.builtin.OutputMode,
    resolved_target: Module.ResolvedTarget,
    is_test: bool,
    have_zcu: bool,
    emit_bin: bool,
    root_optimize_mode: ?std.builtin.OptimizeMode = null,
    root_strip: ?bool = null,
    root_error_tracing: ?bool = null,
    link_mode: ?std.builtin.LinkMode = null,
    ensure_libc_on_non_freestanding: bool = false,
    ensure_libcpp_on_non_freestanding: bool = false,
    any_non_single_threaded: bool = false,
    any_sanitize_thread: bool = false,
    any_unwind_tables: bool = false,
    any_dyn_libs: bool = false,
    any_c_source_files: bool = false,
    any_non_stripped: bool = false,
    any_error_tracing: bool = false,
    emit_llvm_ir: bool = false,
    emit_llvm_bc: bool = false,
    link_libc: ?bool = null,
    link_libcpp: ?bool = null,
    link_libunwind: ?bool = null,
    pie: ?bool = null,
    use_llvm: ?bool = null,
    use_lib_llvm: ?bool = null,
    use_lld: ?bool = null,
    use_clang: ?bool = null,
    lto: ?bool = null,
    /// WASI-only. Type of WASI execution model ("command" or "reactor").
    wasi_exec_model: ?std.builtin.WasiExecModel = null,
    import_memory: ?bool = null,
    export_memory: ?bool = null,
    shared_memory: ?bool = null,
    debug_format: ?DebugFormat = null,
    dll_export_fns: ?bool = null,
    rdynamic: ?bool = null,
};

pub const ResolveError = error{
    WasiExecModelRequiresWasi,
    SharedMemoryIsWasmOnly,
    ObjectFilesCannotShareMemory,
    SharedMemoryRequiresAtomicsAndBulkMemory,
    ThreadsRequireSharedMemory,
    EmittingLlvmModuleRequiresLlvmBackend,
    LlvmLacksTargetSupport,
    ZigLacksTargetSupport,
    EmittingBinaryRequiresLlvmLibrary,
    LldIncompatibleObjectFormat,
    LtoRequiresLld,
    SanitizeThreadRequiresLibCpp,
    LibCppRequiresLibUnwind,
    OsRequiresLibC,
    LibCppRequiresLibC,
    LibUnwindRequiresLibC,
    TargetCannotDynamicLink,
    LibCRequiresDynamicLinking,
    SharedLibrariesRequireDynamicLinking,
    ExportMemoryAndDynamicIncompatible,
    DynamicLibraryPrecludesPie,
    TargetRequiresPie,
    SanitizeThreadRequiresPie,
    BackendLacksErrorTracing,
    LlvmLibraryUnavailable,
    LldUnavailable,
    ClangUnavailable,
    DllExportFnsRequiresWindows,
};

pub fn resolve(options: Options) ResolveError!Config {
    const target = options.resolved_target.result;

    // WASI-only. Resolve the optional exec-model option, defaults to command.
    if (target.os.tag != .wasi and options.wasi_exec_model != null)
        return error.WasiExecModelRequiresWasi;
    const wasi_exec_model = options.wasi_exec_model orelse .command;

    const shared_memory = b: {
        if (!target.cpu.arch.isWasm()) {
            if (options.shared_memory == true) return error.SharedMemoryIsWasmOnly;
            break :b false;
        }
        if (options.output_mode == .Obj) {
            if (options.shared_memory == true) return error.ObjectFilesCannotShareMemory;
            break :b false;
        }
        if (!std.Target.wasm.featureSetHasAll(target.cpu.features, .{ .atomics, .bulk_memory })) {
            if (options.shared_memory == true)
                return error.SharedMemoryRequiresAtomicsAndBulkMemory;
            break :b false;
        }
        if (options.any_non_single_threaded) {
            if (options.shared_memory == false)
                return error.ThreadsRequireSharedMemory;
            break :b true;
        }
        break :b options.shared_memory orelse false;
    };

    // *If* the LLVM backend were to be selected, should Zig use the LLVM
    // library to build the LLVM module?
    const use_lib_llvm = b: {
        if (!build_options.have_llvm) {
            if (options.use_lib_llvm == true) return error.LlvmLibraryUnavailable;
            break :b false;
        }
        break :b options.use_lib_llvm orelse true;
    };

    const root_optimize_mode = options.root_optimize_mode orelse .Debug;

    // Make a decision on whether to use LLVM backend for machine code generation.
    // Note that using the LLVM backend does not necessarily mean using LLVM libraries.
    // For example, Zig can emit .bc and .ll files directly, and this is still considered
    // using "the LLVM backend".
    const use_llvm = b: {
        // If we have no zig code to compile, no need for LLVM.
        if (!options.have_zcu) break :b false;

        // If emitting to LLVM bitcode object format, must use LLVM backend.
        if (options.emit_llvm_ir or options.emit_llvm_bc) {
            if (options.use_llvm == false)
                return error.EmittingLlvmModuleRequiresLlvmBackend;
            if (!target_util.hasLlvmSupport(target, target.ofmt))
                return error.LlvmLacksTargetSupport;

            break :b true;
        }

        // If LLVM does not support the target, then we can't use it.
        if (!target_util.hasLlvmSupport(target, target.ofmt)) {
            if (options.use_llvm == true) return error.LlvmLacksTargetSupport;
            break :b false;
        }

        // If Zig does not support the target, then we can't use it.
        if (target_util.zigBackend(target, false) == .other) {
            if (options.use_llvm == false) return error.ZigLacksTargetSupport;
            break :b true;
        }

        if (options.use_llvm) |x| break :b x;

        // If we cannot use LLVM libraries, then our own backends will be a
        // better default since the LLVM backend can only produce bitcode
        // and not an object file or executable.
        if (!use_lib_llvm and options.emit_bin) break :b false;

        // Prefer LLVM for release builds.
        if (root_optimize_mode != .Debug) break :b true;

        // At this point we would prefer to use our own self-hosted backend,
        // because the compilation speed is better than LLVM. But only do it if
        // we are confident in the robustness of the backend.
        break :b !target_util.selfHostedBackendIsAsRobustAsLlvm(target);
    };

    if (options.emit_bin and options.have_zcu) {
        if (!use_lib_llvm and use_llvm) {
            // Explicit request to use LLVM to produce an object file, but without
            // using LLVM libraries. Impossible.
            return error.EmittingBinaryRequiresLlvmLibrary;
        }

        if (target_util.zigBackend(target, use_llvm) == .other) {
            // There is no compiler backend available for this target.
            return error.ZigLacksTargetSupport;
        }
    }

    // Make a decision on whether to use LLD or our own linker.
    const use_lld = b: {
        if (!target_util.hasLldSupport(target.ofmt)) {
            if (options.use_lld == true) return error.LldIncompatibleObjectFormat;
            break :b false;
        }

        if (!build_options.have_llvm) {
            if (options.use_lld == true) return error.LldUnavailable;
            break :b false;
        }

        if (options.lto == true) {
            if (options.use_lld == false) return error.LtoRequiresLld;
            break :b true;
        }

        if (options.use_lld) |x| break :b x;
        break :b true;
    };

    // Make a decision on whether to use Clang or Aro for translate-c and compiling C files.
    const c_frontend: CFrontend = b: {
        if (!build_options.have_llvm) {
            if (options.use_clang == true) return error.ClangUnavailable;
            break :b .aro;
        }
        if (options.use_clang) |clang| {
            break :b if (clang) .clang else .aro;
        }
        break :b .clang;
    };

    const lto = b: {
        if (!use_lld) {
            // zig ld LTO support is tracked by
            // https://github.com/ziglang/zig/issues/8680
            if (options.lto == true) return error.LtoRequiresLld;
            break :b false;
        }

        if (options.lto) |x| break :b x;
        if (!options.any_c_source_files) break :b false;

        if (target.cpu.arch.isRISCV()) {
            // Clang and LLVM currently don't support RISC-V target-abi for LTO.
            // Compiling with LTO may fail or produce undesired results.
            // See https://reviews.llvm.org/D71387
            // See https://reviews.llvm.org/D102582
            break :b false;
        }

        break :b switch (options.output_mode) {
            .Lib, .Obj => false,
            .Exe => switch (root_optimize_mode) {
                .Debug => false,
                .ReleaseSafe, .ReleaseFast, .ReleaseSmall => true,
            },
        };
    };

    const link_libcpp = b: {
        if (options.link_libcpp == true) break :b true;
        if (options.any_sanitize_thread) {
            // TSAN is (for now...) implemented in C++ so it requires linking libc++.
            if (options.link_libcpp == false) return error.SanitizeThreadRequiresLibCpp;
            break :b true;
        }
        if (options.ensure_libcpp_on_non_freestanding and target.os.tag != .freestanding)
            break :b true;

        break :b false;
    };

    const link_libunwind = b: {
        if (link_libcpp and target_util.libcNeedsLibUnwind(target)) {
            if (options.link_libunwind == false) return error.LibCppRequiresLibUnwind;
            break :b true;
        }
        break :b options.link_libunwind orelse false;
    };

    const link_libc = b: {
        if (target_util.osRequiresLibC(target)) {
            if (options.link_libc == false) return error.OsRequiresLibC;
            break :b true;
        }
        if (link_libcpp) {
            if (options.link_libc == false) return error.LibCppRequiresLibC;
            break :b true;
        }
        if (link_libunwind) {
            if (options.link_libc == false) return error.LibUnwindRequiresLibC;
            break :b true;
        }
        if (options.link_libc) |x| break :b x;
        if (options.ensure_libc_on_non_freestanding and target.os.tag != .freestanding)
            break :b true;

        break :b false;
    };

    const any_unwind_tables = options.any_unwind_tables or
        link_libunwind or target_util.needUnwindTables(target);

    const link_mode = b: {
        const explicitly_exe_or_dyn_lib = switch (options.output_mode) {
            .Obj => false,
            .Lib => (options.link_mode orelse .static) == .dynamic,
            .Exe => true,
        };

        if (target_util.cannotDynamicLink(target)) {
            if (options.link_mode == .dynamic) return error.TargetCannotDynamicLink;
            break :b .static;
        }
        if (explicitly_exe_or_dyn_lib and link_libc and
            (target.isGnuLibC() or target_util.osRequiresLibC(target)))
        {
            if (options.link_mode == .static) return error.LibCRequiresDynamicLinking;
            break :b .dynamic;
        }
        // When creating a executable that links to system libraries, we
        // require dynamic linking, but we must not link static libraries
        // or object files dynamically!
        if (options.any_dyn_libs and options.output_mode == .Exe) {
            if (options.link_mode == .static) return error.SharedLibrariesRequireDynamicLinking;
            break :b .dynamic;
        }

        if (options.link_mode) |link_mode| break :b link_mode;

        if (explicitly_exe_or_dyn_lib and link_libc and
            options.resolved_target.is_native_abi and target.abi.isMusl())
        {
            // If targeting the system's native ABI and the system's libc is
            // musl, link dynamically by default.
            break :b .dynamic;
        }

        // Static is generally a better default. Fight me.
        break :b .static;
    };

    const import_memory = options.import_memory orelse (options.output_mode == .Obj);
    const export_memory = b: {
        if (link_mode == .dynamic) {
            if (options.export_memory == true) return error.ExportMemoryAndDynamicIncompatible;
            break :b false;
        }
        if (options.export_memory) |x| break :b x;
        break :b !import_memory;
    };

    const pie: bool = b: {
        switch (options.output_mode) {
            .Obj, .Exe => {},
            .Lib => if (link_mode == .dynamic) {
                if (options.pie == true) return error.DynamicLibraryPrecludesPie;
                break :b false;
            },
        }
        if (target_util.requiresPIE(target)) {
            if (options.pie == false) return error.TargetRequiresPie;
            break :b true;
        }
        if (options.any_sanitize_thread) {
            if (options.pie == false) return error.SanitizeThreadRequiresPie;
            break :b true;
        }
        if (options.pie) |pie| break :b pie;
        break :b false;
    };

    const root_strip = b: {
        if (options.root_strip) |x| break :b x;
        if (root_optimize_mode == .ReleaseSmall) break :b true;
        if (!target_util.hasDebugInfo(target)) break :b true;
        break :b false;
    };

    const debug_format: DebugFormat = b: {
        if (root_strip and !options.any_non_stripped) break :b .strip;
        break :b switch (target.ofmt) {
            .elf, .macho, .wasm => .{ .dwarf = .@"32" },
            .coff => .code_view,
            .c => switch (target.os.tag) {
                .windows, .uefi => .code_view,
                else => .{ .dwarf = .@"32" },
            },
            .spirv, .nvptx, .dxcontainer, .hex, .raw, .plan9 => .strip,
        };
    };

    const backend_supports_error_tracing = target_util.backendSupportsFeature(
        target.cpu.arch,
        target.ofmt,
        use_llvm,
        .error_return_trace,
    );

    const root_error_tracing = b: {
        if (options.root_error_tracing) |x| break :b x;
        if (root_strip) break :b false;
        if (!backend_supports_error_tracing) break :b false;
        break :b switch (root_optimize_mode) {
            .Debug => true,
            .ReleaseSafe, .ReleaseFast, .ReleaseSmall => false,
        };
    };

    const any_error_tracing = root_error_tracing or options.any_error_tracing;
    if (any_error_tracing and !backend_supports_error_tracing)
        return error.BackendLacksErrorTracing;

    const rdynamic = options.rdynamic orelse false;

    const dll_export_fns = b: {
        if (target.os.tag != .windows) {
            if (options.dll_export_fns == true)
                return error.DllExportFnsRequiresWindows;
            break :b false;
        }
        if (options.dll_export_fns) |x| break :b x;
        if (rdynamic) break :b true;
        break :b switch (options.output_mode) {
            .Obj, .Exe => false,
            .Lib => link_mode == .dynamic,
        };
    };

    return .{
        .output_mode = options.output_mode,
        .have_zcu = options.have_zcu,
        .is_test = options.is_test,
        .link_mode = link_mode,
        .link_libc = link_libc,
        .link_libcpp = link_libcpp,
        .link_libunwind = link_libunwind,
        .any_unwind_tables = any_unwind_tables,
        .any_c_source_files = options.any_c_source_files,
        .any_non_single_threaded = options.any_non_single_threaded,
        .any_error_tracing = any_error_tracing,
        .any_sanitize_thread = options.any_sanitize_thread,
        .root_error_tracing = root_error_tracing,
        .pie = pie,
        .lto = lto,
        .import_memory = import_memory,
        .export_memory = export_memory,
        .shared_memory = shared_memory,
        .c_frontend = c_frontend,
        .use_llvm = use_llvm,
        .use_lib_llvm = use_lib_llvm,
        .use_lld = use_lld,
        .wasi_exec_model = wasi_exec_model,
        .debug_format = debug_format,
        .root_strip = root_strip,
        .dll_export_fns = dll_export_fns,
        .rdynamic = rdynamic,
    };
}

const std = @import("std");
const Module = @import("../Package.zig").Module;
const Config = @This();
const target_util = @import("../target.zig");
const build_options = @import("build_options");
