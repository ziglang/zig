//! This is the main entry point for the Zig/C++ hybrid compiler (stage1).
//! It has the functions exported from Zig, called in C++, and bindings for
//! the functions exported from C++, called from Zig.

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;

const build_options = @import("build_options");
const stage2 = @import("main.zig");
const fatal = stage2.fatal;
const Compilation = @import("Compilation.zig");
const translate_c = @import("translate_c.zig");
const target_util = @import("target.zig");

comptime {
    assert(std.builtin.link_libc);
    assert(build_options.is_stage1);
    assert(build_options.have_llvm);
    _ = @import("compiler_rt");
}

pub const log = stage2.log;
pub const log_level = stage2.log_level;

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    std.os.argv = argv[0..@intCast(usize, argc)];

    std.debug.maybeEnableSegfaultHandler();

    zig_stage1_os_init();

    const gpa = std.heap.c_allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = &arena_instance.allocator;

    const args = arena.alloc([]const u8, @intCast(usize, argc)) catch fatal("{}", .{"OutOfMemory"});
    for (args) |*arg, i| {
        arg.* = mem.spanZ(argv[i]);
    }
    if (std.builtin.mode == .Debug) {
        stage2.mainArgs(gpa, arena, args) catch unreachable;
    } else {
        stage2.mainArgs(gpa, arena, args) catch |err| fatal("{}", .{@errorName(err)});
    }
    return 0;
}

/// Matches stage2.Color;
pub const ErrColor = c_int;
/// Matches std.builtin.CodeModel
pub const CodeModel = c_int;
/// Matches std.Target.Os.Tag
pub const OS = c_int;
/// Matches std.builtin.BuildMode
pub const BuildMode = c_int;

pub const TargetSubsystem = extern enum(c_int) {
    Console,
    Windows,
    Posix,
    Native,
    EfiApplication,
    EfiBootServiceDriver,
    EfiRom,
    EfiRuntimeDriver,
    Auto,
};

pub const Pkg = extern struct {
    name_ptr: [*]const u8,
    name_len: usize,
    path_ptr: [*]const u8,
    path_len: usize,
    children_ptr: [*]*Pkg,
    children_len: usize,
    parent: ?*Pkg,
};

pub const Module = extern struct {
    root_name_ptr: [*]const u8,
    root_name_len: usize,
    emit_o_ptr: [*]const u8,
    emit_o_len: usize,
    emit_h_ptr: [*]const u8,
    emit_h_len: usize,
    emit_asm_ptr: [*]const u8,
    emit_asm_len: usize,
    emit_llvm_ir_ptr: [*]const u8,
    emit_llvm_ir_len: usize,
    emit_analysis_json_ptr: [*]const u8,
    emit_analysis_json_len: usize,
    emit_docs_ptr: [*]const u8,
    emit_docs_len: usize,
    builtin_zig_path_ptr: [*]const u8,
    builtin_zig_path_len: usize,
    test_filter_ptr: [*]const u8,
    test_filter_len: usize,
    test_name_prefix_ptr: [*]const u8,
    test_name_prefix_len: usize,
    userdata: usize,
    root_pkg: *Pkg,
    main_progress_node: ?*std.Progress.Node,
    code_model: CodeModel,
    subsystem: TargetSubsystem,
    err_color: ErrColor,
    pic: bool,
    pie: bool,
    link_libc: bool,
    link_libcpp: bool,
    strip: bool,
    is_single_threaded: bool,
    dll_export_fns: bool,
    link_mode_dynamic: bool,
    valgrind_enabled: bool,
    function_sections: bool,
    enable_stack_probing: bool,
    enable_time_report: bool,
    enable_stack_report: bool,
    test_is_evented: bool,
    verbose_tokenize: bool,
    verbose_ast: bool,
    verbose_ir: bool,
    verbose_llvm_ir: bool,
    verbose_cimport: bool,
    verbose_llvm_cpu_features: bool,

    // Set by stage1
    have_c_main: bool,
    have_winmain: bool,
    have_wwinmain: bool,
    have_winmain_crt_startup: bool,
    have_wwinmain_crt_startup: bool,
    have_dllmain_crt_startup: bool,

    pub fn build_object(mod: *Module) void {
        zig_stage1_build_object(mod);
    }

    pub fn destroy(mod: *Module) void {
        zig_stage1_destroy(mod);
    }
};

extern fn zig_stage1_os_init() void;

pub const create = zig_stage1_create;
extern fn zig_stage1_create(
    optimize_mode: BuildMode,
    main_pkg_path_ptr: [*]const u8,
    main_pkg_path_len: usize,
    root_src_path_ptr: [*]const u8,
    root_src_path_len: usize,
    zig_lib_dir_ptr: [*c]const u8,
    zig_lib_dir_len: usize,
    target: [*c]const Stage2Target,
    is_test_build: bool,
) ?*Module;

extern fn zig_stage1_build_object(*Module) void;
extern fn zig_stage1_destroy(*Module) void;

// ABI warning
export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}

// ABI warning
const Error = extern enum {
    None,
    OutOfMemory,
    InvalidFormat,
    SemanticAnalyzeFail,
    AccessDenied,
    Interrupted,
    SystemResources,
    FileNotFound,
    FileSystem,
    FileTooBig,
    DivByZero,
    Overflow,
    PathAlreadyExists,
    Unexpected,
    ExactDivRemainder,
    NegativeDenominator,
    ShiftedOutOneBits,
    CCompileErrors,
    EndOfFile,
    IsDir,
    NotDir,
    UnsupportedOperatingSystem,
    SharingViolation,
    PipeBusy,
    PrimitiveTypeNotFound,
    CacheUnavailable,
    PathTooLong,
    CCompilerCannotFindFile,
    NoCCompilerInstalled,
    ReadingDepFile,
    InvalidDepFile,
    MissingArchitecture,
    MissingOperatingSystem,
    UnknownArchitecture,
    UnknownOperatingSystem,
    UnknownABI,
    InvalidFilename,
    DiskQuota,
    DiskSpace,
    UnexpectedWriteFailure,
    UnexpectedSeekFailure,
    UnexpectedFileTruncationFailure,
    Unimplemented,
    OperationAborted,
    BrokenPipe,
    NoSpaceLeft,
    NotLazy,
    IsAsync,
    ImportOutsidePkgPath,
    UnknownCpuModel,
    UnknownCpuFeature,
    InvalidCpuFeatures,
    InvalidLlvmCpuFeaturesFormat,
    UnknownApplicationBinaryInterface,
    ASTUnitFailure,
    BadPathName,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    DeviceBusy,
    UnableToSpawnCCompiler,
    CCompilerExitCode,
    CCompilerCrashed,
    CCompilerCannotFindHeaders,
    LibCRuntimeNotFound,
    LibCStdLibHeaderNotFound,
    LibCKernel32LibNotFound,
    UnsupportedArchitecture,
    WindowsSdkNotFound,
    UnknownDynamicLinkerPath,
    TargetHasNoDynamicLinker,
    InvalidAbiVersion,
    InvalidOperatingSystemVersion,
    UnknownClangOption,
    NestedResponseFile,
    ZigIsTheCCompiler,
    FileBusy,
    Locked,
};

// ABI warning
export fn stage2_attach_segfault_handler() void {
    if (std.debug.runtime_safety and std.debug.have_segfault_handling_support) {
        std.debug.attachSegfaultHandler();
    }
}

// ABI warning
export fn stage2_progress_create() *std.Progress {
    const ptr = std.heap.c_allocator.create(std.Progress) catch @panic("out of memory");
    ptr.* = std.Progress{};
    return ptr;
}

// ABI warning
export fn stage2_progress_destroy(progress: *std.Progress) void {
    std.heap.c_allocator.destroy(progress);
}

// ABI warning
export fn stage2_progress_start_root(
    progress: *std.Progress,
    name_ptr: [*]const u8,
    name_len: usize,
    estimated_total_items: usize,
) *std.Progress.Node {
    return progress.start(
        name_ptr[0..name_len],
        if (estimated_total_items == 0) null else estimated_total_items,
    ) catch @panic("timer unsupported");
}

// ABI warning
export fn stage2_progress_disable_tty(progress: *std.Progress) void {
    progress.terminal = null;
}

// ABI warning
export fn stage2_progress_start(
    node: *std.Progress.Node,
    name_ptr: [*]const u8,
    name_len: usize,
    estimated_total_items: usize,
) *std.Progress.Node {
    const child_node = std.heap.c_allocator.create(std.Progress.Node) catch @panic("out of memory");
    child_node.* = node.start(
        name_ptr[0..name_len],
        if (estimated_total_items == 0) null else estimated_total_items,
    );
    child_node.activate();
    return child_node;
}

// ABI warning
export fn stage2_progress_end(node: *std.Progress.Node) void {
    node.end();
    if (&node.context.root != node) {
        std.heap.c_allocator.destroy(node);
    }
}

// ABI warning
export fn stage2_progress_complete_one(node: *std.Progress.Node) void {
    node.completeOne();
}

// ABI warning
export fn stage2_progress_update_node(node: *std.Progress.Node, done_count: usize, total_count: usize) void {
    node.completed_items = done_count;
    node.estimated_total_items = total_count;
    node.activate();
    node.context.maybeRefresh();
}

// ABI warning
pub const Stage2Target = extern struct {
    arch: c_int,
    os: OS,
    abi: c_int,

    is_native_os: bool,
    is_native_cpu: bool,

    llvm_cpu_name: ?[*:0]const u8,
    llvm_cpu_features: ?[*:0]const u8,
};

// ABI warning
const Stage2SemVer = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
};

// ABI warning
export fn stage2_cimport(
    stage1: *Module,
    c_src_ptr: [*]const u8,
    c_src_len: usize,
    out_zig_path_ptr: *[*]const u8,
    out_zig_path_len: *usize,
    out_errors_ptr: *[*]translate_c.ClangErrMsg,
    out_errors_len: *usize,
) Error {
    const comp = @intToPtr(*Compilation, stage1.userdata);
    const c_src = c_src_ptr[0..c_src_len];
    const result = comp.cImport(c_src) catch |err| switch (err) {
        error.SystemResources => return .SystemResources,
        error.OperationAborted => return .OperationAborted,
        error.BrokenPipe => return .BrokenPipe,
        error.DiskQuota => return .DiskQuota,
        error.FileTooBig => return .FileTooBig,
        error.NoSpaceLeft => return .NoSpaceLeft,
        error.AccessDenied => return .AccessDenied,
        error.OutOfMemory => return .OutOfMemory,
        error.Unexpected => return .Unexpected,
        error.InputOutput => return .FileSystem,
        error.ASTUnitFailure => return .ASTUnitFailure,
        error.CacheUnavailable => return .CacheUnavailable,
        else => return .Unexpected,
    };
    out_zig_path_ptr.* = result.out_zig_path.ptr;
    out_zig_path_len.* = result.out_zig_path.len;
    out_errors_ptr.* = result.errors.ptr;
    out_errors_len.* = result.errors.len;
    if (result.errors.len != 0) return .CCompileErrors;
    return Error.None;
}

export fn stage2_add_link_lib(
    stage1: *Module,
    lib_name_ptr: [*c]const u8,
    lib_name_len: usize,
    symbol_name_ptr: [*c]const u8,
    symbol_name_len: usize,
) ?[*:0]const u8 {
    const comp = @intToPtr(*Compilation, stage1.userdata);
    const lib_name = std.ascii.allocLowerString(comp.gpa, lib_name_ptr[0..lib_name_len]) catch return "out of memory";
    const target = comp.getTarget();
    const is_libc = target_util.is_libc_lib_name(target, lib_name);
    if (is_libc) {
        if (!comp.bin_file.options.link_libc) {
            return "dependency on libc must be explicitly specified in the build command";
        }
        return null;
    }
    if (target_util.is_libcpp_lib_name(target, lib_name)) {
        if (!comp.bin_file.options.link_libcpp) {
            return "dependency on libc++ must be explicitly specified in the build command";
        }
        return null;
    }
    if (!target.isWasm() and !comp.bin_file.options.pic) {
        return std.fmt.allocPrint0(
            comp.gpa,
            "dependency on dynamic library '{s}' requires enabling Position Independent Code. Fixed by `-l{s}` or `-fPIC`.",
            .{ lib_name, lib_name },
        ) catch "out of memory";
    }
    comp.stage1AddLinkLib(lib_name) catch |err| {
        return std.fmt.allocPrint0(comp.gpa, "unable to add link lib '{s}': {s}", .{
            lib_name, @errorName(err),
        }) catch "out of memory";
    };
    return null;
}

export fn stage2_fetch_file(
    stage1: *Module,
    path_ptr: [*]const u8,
    path_len: usize,
    result_len: *usize,
) ?[*]const u8 {
    const comp = @intToPtr(*Compilation, stage1.userdata);
    const file_path = path_ptr[0..path_len];
    const max_file_size = std.math.maxInt(u32);
    const contents = comp.stage1_cache_manifest.addFilePostFetch(file_path, max_file_size) catch return null;
    result_len.* = contents.len;
    // TODO https://github.com/ziglang/zig/issues/3328#issuecomment-716749475
    if (contents.len == 0) return @intToPtr(?[*]const u8, 0x1);
    return contents.ptr;
}
