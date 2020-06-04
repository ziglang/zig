// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.

const std = @import("std");
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListSentineled = std.ArrayListSentineled;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const self_hosted_main = @import("main.zig");
const DepTokenizer = @import("dep_tokenizer.zig").Tokenizer;
const assert = std.debug.assert;
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;

var stderr_file: fs.File = undefined;
var stderr: fs.File.OutStream = undefined;
var stdout: fs.File.OutStream = undefined;

comptime {
    _ = @import("dep_tokenizer.zig");
}

// ABI warning
export fn stage2_zen(ptr: *[*]const u8, len: *usize) void {
    const info_zen = @import("main.zig").info_zen;
    ptr.* = info_zen;
    len.* = info_zen.len;
}

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

const FILE = std.c.FILE;
const ast = std.zig.ast;
const translate_c = @import("translate_c.zig");

/// Args should have a null terminating last arg.
export fn stage2_translate_c(
    out_ast: **ast.Tree,
    out_errors_ptr: *[*]translate_c.ClangErrMsg,
    out_errors_len: *usize,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    resources_path: [*:0]const u8,
) Error {
    var errors: []translate_c.ClangErrMsg = &[0]translate_c.ClangErrMsg{};
    out_ast.* = translate_c.translate(std.heap.c_allocator, args_begin, args_end, &errors, resources_path) catch |err| switch (err) {
        error.SemanticAnalyzeFail => {
            out_errors_ptr.* = errors.ptr;
            out_errors_len.* = errors.len;
            return .CCompileErrors;
        },
        error.ASTUnitFailure => return .ASTUnitFailure,
        error.OutOfMemory => return .OutOfMemory,
    };
    return .None;
}

export fn stage2_free_clang_errors(errors_ptr: [*]translate_c.ClangErrMsg, errors_len: usize) void {
    translate_c.freeErrors(errors_ptr[0..errors_len]);
}

export fn stage2_render_ast(tree: *ast.Tree, output_file: *FILE) Error {
    const c_out_stream = std.io.cOutStream(output_file);
    _ = std.zig.render(std.heap.c_allocator, c_out_stream, tree) catch |e| switch (e) {
        error.WouldBlock => unreachable, // stage1 opens stuff in exclusively blocking mode
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
    };
    return .None;
}

export fn stage2_fmt(argc: c_int, argv: [*]const [*:0]const u8) c_int {
    if (std.debug.runtime_safety) {
        fmtMain(argc, argv) catch unreachable;
    } else {
        fmtMain(argc, argv) catch |e| {
            std.debug.warn("{}\n", .{@errorName(e)});
            return -1;
        };
    }
    return 0;
}

fn fmtMain(argc: c_int, argv: [*]const [*:0]const u8) !void {
    const allocator = std.heap.c_allocator;
    var args_list = std.ArrayList([]const u8).init(allocator);
    const argc_usize = @intCast(usize, argc);
    var arg_i: usize = 0;
    while (arg_i < argc_usize) : (arg_i += 1) {
        try args_list.append(mem.spanZ(argv[arg_i]));
    }

    const args = args_list.span()[2..];

    return self_hosted_main.cmdFmt(allocator, args);
}

export fn stage2_DepTokenizer_init(input: [*]const u8, len: usize) stage2_DepTokenizer {
    const t = std.heap.c_allocator.create(DepTokenizer) catch @panic("failed to create .d tokenizer");
    t.* = DepTokenizer.init(std.heap.c_allocator, input[0..len]);
    return stage2_DepTokenizer{
        .handle = t,
    };
}

export fn stage2_DepTokenizer_deinit(self: *stage2_DepTokenizer) void {
    self.handle.deinit();
}

export fn stage2_DepTokenizer_next(self: *stage2_DepTokenizer) stage2_DepNextResult {
    const otoken = self.handle.next() catch {
        const textz = std.ArrayListSentineled(u8, 0).init(&self.handle.arena.allocator, self.handle.error_text) catch @panic("failed to create .d tokenizer error text");
        return stage2_DepNextResult{
            .type_id = .error_,
            .textz = textz.span().ptr,
        };
    };
    const token = otoken orelse {
        return stage2_DepNextResult{
            .type_id = .null_,
            .textz = undefined,
        };
    };
    const textz = std.ArrayListSentineled(u8, 0).init(&self.handle.arena.allocator, token.bytes) catch @panic("failed to create .d tokenizer token text");
    return stage2_DepNextResult{
        .type_id = switch (token.id) {
            .target => .target,
            .prereq => .prereq,
        },
        .textz = textz.span().ptr,
    };
}

const stage2_DepTokenizer = extern struct {
    handle: *DepTokenizer,
};

const stage2_DepNextResult = extern struct {
    type_id: TypeId,

    // when type_id == error --> error text
    // when type_id == null --> undefined
    // when type_id == target --> target pathname
    // when type_id == prereq --> prereq pathname
    textz: [*]const u8,

    const TypeId = extern enum {
        error_,
        null_,
        target,
        prereq,
    };
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

fn detectNativeCpuWithLLVM(
    arch: Target.Cpu.Arch,
    llvm_cpu_name_z: ?[*:0]const u8,
    llvm_cpu_features_opt: ?[*:0]const u8,
) !Target.Cpu {
    var result = Target.Cpu.baseline(arch);

    if (llvm_cpu_name_z) |cpu_name_z| {
        const llvm_cpu_name = mem.spanZ(cpu_name_z);

        for (arch.allCpuModels()) |model| {
            const this_llvm_name = model.llvm_name orelse continue;
            if (mem.eql(u8, this_llvm_name, llvm_cpu_name)) {
                // Here we use the non-dependencies-populated set,
                // so that subtracting features later in this function
                // affect the prepopulated set.
                result = Target.Cpu{
                    .arch = arch,
                    .model = model,
                    .features = model.features,
                };
                break;
            }
        }
    }

    const all_features = arch.allFeaturesList();

    if (llvm_cpu_features_opt) |llvm_cpu_features| {
        var it = mem.tokenize(mem.spanZ(llvm_cpu_features), ",");
        while (it.next()) |decorated_llvm_feat| {
            var op: enum {
                add,
                sub,
            } = undefined;
            var llvm_feat: []const u8 = undefined;
            if (mem.startsWith(u8, decorated_llvm_feat, "+")) {
                op = .add;
                llvm_feat = decorated_llvm_feat[1..];
            } else if (mem.startsWith(u8, decorated_llvm_feat, "-")) {
                op = .sub;
                llvm_feat = decorated_llvm_feat[1..];
            } else {
                return error.InvalidLlvmCpuFeaturesFormat;
            }
            for (all_features) |feature, index_usize| {
                const this_llvm_name = feature.llvm_name orelse continue;
                if (mem.eql(u8, llvm_feat, this_llvm_name)) {
                    const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
                    switch (op) {
                        .add => result.features.addFeature(index),
                        .sub => result.features.removeFeature(index),
                    }
                    break;
                }
            }
        }
    }

    result.features.populateDependencies(all_features);
    return result;
}

// ABI warning
export fn stage2_cmd_targets(
    zig_triple: ?[*:0]const u8,
    mcpu: ?[*:0]const u8,
    dynamic_linker: ?[*:0]const u8,
) c_int {
    cmdTargets(zig_triple, mcpu, dynamic_linker) catch |err| {
        std.debug.warn("unable to list targets: {}\n", .{@errorName(err)});
        return -1;
    };
    return 0;
}

fn cmdTargets(
    zig_triple_oz: ?[*:0]const u8,
    mcpu_oz: ?[*:0]const u8,
    dynamic_linker_oz: ?[*:0]const u8,
) !void {
    const cross_target = try stage2CrossTarget(zig_triple_oz, mcpu_oz, dynamic_linker_oz);
    var dynamic_linker: ?[*:0]u8 = null;
    const target = try crossTargetToTarget(cross_target, &dynamic_linker);
    return @import("print_targets.zig").cmdTargets(
        std.heap.c_allocator,
        &[0][]u8{},
        std.io.getStdOut().outStream(),
        target,
    );
}

// ABI warning
export fn stage2_target_parse(
    target: *Stage2Target,
    zig_triple: ?[*:0]const u8,
    mcpu: ?[*:0]const u8,
    dynamic_linker: ?[*:0]const u8,
) Error {
    stage2TargetParse(target, zig_triple, mcpu, dynamic_linker) catch |err| switch (err) {
        error.OutOfMemory => return .OutOfMemory,
        error.UnknownArchitecture => return .UnknownArchitecture,
        error.UnknownOperatingSystem => return .UnknownOperatingSystem,
        error.UnknownApplicationBinaryInterface => return .UnknownApplicationBinaryInterface,
        error.MissingOperatingSystem => return .MissingOperatingSystem,
        error.InvalidLlvmCpuFeaturesFormat => return .InvalidLlvmCpuFeaturesFormat,
        error.UnexpectedExtraField => return .SemanticAnalyzeFail,
        error.InvalidAbiVersion => return .InvalidAbiVersion,
        error.InvalidOperatingSystemVersion => return .InvalidOperatingSystemVersion,
        error.FileSystem => return .FileSystem,
        error.SymLinkLoop => return .SymLinkLoop,
        error.SystemResources => return .SystemResources,
        error.ProcessFdQuotaExceeded => return .ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded => return .SystemFdQuotaExceeded,
        error.DeviceBusy => return .DeviceBusy,
    };
    return .None;
}

fn stage2CrossTarget(
    zig_triple_oz: ?[*:0]const u8,
    mcpu_oz: ?[*:0]const u8,
    dynamic_linker_oz: ?[*:0]const u8,
) !CrossTarget {
    const mcpu = mem.spanZ(mcpu_oz);
    const dynamic_linker = mem.spanZ(dynamic_linker_oz);
    var diags: CrossTarget.ParseOptions.Diagnostics = .{};
    const target: CrossTarget = CrossTarget.parse(.{
        .arch_os_abi = mem.spanZ(zig_triple_oz) orelse "native",
        .cpu_features = mcpu,
        .dynamic_linker = dynamic_linker,
        .diagnostics = &diags,
    }) catch |err| switch (err) {
        error.UnknownCpuModel => {
            std.debug.warn("Unknown CPU: '{}'\nAvailable CPUs for architecture '{}':\n", .{
                diags.cpu_name.?,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allCpuModels()) |cpu| {
                std.debug.warn(" {}\n", .{cpu.name});
            }
            process.exit(1);
        },
        error.UnknownCpuFeature => {
            std.debug.warn(
                \\Unknown CPU feature: '{}'
                \\Available CPU features for architecture '{}':
                \\
            , .{
                diags.unknown_feature_name,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allFeaturesList()) |feature| {
                std.debug.warn(" {}: {}\n", .{ feature.name, feature.description });
            }
            process.exit(1);
        },
        else => |e| return e,
    };

    return target;
}

fn stage2TargetParse(
    stage1_target: *Stage2Target,
    zig_triple_oz: ?[*:0]const u8,
    mcpu_oz: ?[*:0]const u8,
    dynamic_linker_oz: ?[*:0]const u8,
) !void {
    const target = try stage2CrossTarget(zig_triple_oz, mcpu_oz, dynamic_linker_oz);
    try stage1_target.fromTarget(target);
}

// ABI warning
const Stage2LibCInstallation = extern struct {
    include_dir: [*]const u8,
    include_dir_len: usize,
    sys_include_dir: [*]const u8,
    sys_include_dir_len: usize,
    crt_dir: [*]const u8,
    crt_dir_len: usize,
    msvc_lib_dir: [*]const u8,
    msvc_lib_dir_len: usize,
    kernel32_lib_dir: [*]const u8,
    kernel32_lib_dir_len: usize,

    fn initFromStage2(self: *Stage2LibCInstallation, libc: LibCInstallation) void {
        if (libc.include_dir) |s| {
            self.include_dir = s.ptr;
            self.include_dir_len = s.len;
        } else {
            self.include_dir = "";
            self.include_dir_len = 0;
        }
        if (libc.sys_include_dir) |s| {
            self.sys_include_dir = s.ptr;
            self.sys_include_dir_len = s.len;
        } else {
            self.sys_include_dir = "";
            self.sys_include_dir_len = 0;
        }
        if (libc.crt_dir) |s| {
            self.crt_dir = s.ptr;
            self.crt_dir_len = s.len;
        } else {
            self.crt_dir = "";
            self.crt_dir_len = 0;
        }
        if (libc.msvc_lib_dir) |s| {
            self.msvc_lib_dir = s.ptr;
            self.msvc_lib_dir_len = s.len;
        } else {
            self.msvc_lib_dir = "";
            self.msvc_lib_dir_len = 0;
        }
        if (libc.kernel32_lib_dir) |s| {
            self.kernel32_lib_dir = s.ptr;
            self.kernel32_lib_dir_len = s.len;
        } else {
            self.kernel32_lib_dir = "";
            self.kernel32_lib_dir_len = 0;
        }
    }

    fn toStage2(self: Stage2LibCInstallation) LibCInstallation {
        var libc: LibCInstallation = .{};
        if (self.include_dir_len != 0) {
            libc.include_dir = self.include_dir[0..self.include_dir_len];
        }
        if (self.sys_include_dir_len != 0) {
            libc.sys_include_dir = self.sys_include_dir[0..self.sys_include_dir_len];
        }
        if (self.crt_dir_len != 0) {
            libc.crt_dir = self.crt_dir[0..self.crt_dir_len];
        }
        if (self.msvc_lib_dir_len != 0) {
            libc.msvc_lib_dir = self.msvc_lib_dir[0..self.msvc_lib_dir_len];
        }
        if (self.kernel32_lib_dir_len != 0) {
            libc.kernel32_lib_dir = self.kernel32_lib_dir[0..self.kernel32_lib_dir_len];
        }
        return libc;
    }
};

// ABI warning
export fn stage2_libc_parse(stage1_libc: *Stage2LibCInstallation, libc_file_z: [*:0]const u8) Error {
    stderr_file = std.io.getStdErr();
    stderr = stderr_file.outStream();
    const libc_file = mem.spanZ(libc_file_z);
    var libc = LibCInstallation.parse(std.heap.c_allocator, libc_file, stderr) catch |err| switch (err) {
        error.ParseError => return .SemanticAnalyzeFail,
        error.DiskQuota => return .DiskQuota,
        error.FileTooBig => return .FileTooBig,
        error.InputOutput => return .FileSystem,
        error.NoSpaceLeft => return .NoSpaceLeft,
        error.AccessDenied => return .AccessDenied,
        error.BrokenPipe => return .BrokenPipe,
        error.SystemResources => return .SystemResources,
        error.OperationAborted => return .OperationAborted,
        error.WouldBlock => unreachable,
        error.Unexpected => return .Unexpected,
        error.EndOfStream => return .EndOfFile,
        error.IsDir => return .IsDir,
        error.ConnectionResetByPeer => unreachable,
        error.ConnectionTimedOut => unreachable,
        error.OutOfMemory => return .OutOfMemory,
        error.Unseekable => unreachable,
        error.SharingViolation => return .SharingViolation,
        error.PathAlreadyExists => unreachable,
        error.FileNotFound => return .FileNotFound,
        error.PipeBusy => return .PipeBusy,
        error.NameTooLong => return .PathTooLong,
        error.InvalidUtf8 => return .BadPathName,
        error.BadPathName => return .BadPathName,
        error.SymLinkLoop => return .SymLinkLoop,
        error.ProcessFdQuotaExceeded => return .ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded => return .SystemFdQuotaExceeded,
        error.NoDevice => return .NoDevice,
        error.NotDir => return .NotDir,
        error.DeviceBusy => return .DeviceBusy,
        error.FileLocksNotSupported => unreachable,
    };
    stage1_libc.initFromStage2(libc);
    return .None;
}

// ABI warning
export fn stage2_libc_find_native(stage1_libc: *Stage2LibCInstallation) Error {
    var libc = LibCInstallation.findNative(.{
        .allocator = std.heap.c_allocator,
        .verbose = true,
    }) catch |err| switch (err) {
        error.OutOfMemory => return .OutOfMemory,
        error.FileSystem => return .FileSystem,
        error.UnableToSpawnCCompiler => return .UnableToSpawnCCompiler,
        error.CCompilerExitCode => return .CCompilerExitCode,
        error.CCompilerCrashed => return .CCompilerCrashed,
        error.CCompilerCannotFindHeaders => return .CCompilerCannotFindHeaders,
        error.LibCRuntimeNotFound => return .LibCRuntimeNotFound,
        error.LibCStdLibHeaderNotFound => return .LibCStdLibHeaderNotFound,
        error.LibCKernel32LibNotFound => return .LibCKernel32LibNotFound,
        error.UnsupportedArchitecture => return .UnsupportedArchitecture,
        error.WindowsSdkNotFound => return .WindowsSdkNotFound,
        error.ZigIsTheCCompiler => return .ZigIsTheCCompiler,
    };
    stage1_libc.initFromStage2(libc);
    return .None;
}

// ABI warning
export fn stage2_libc_render(stage1_libc: *Stage2LibCInstallation, output_file: *FILE) Error {
    var libc = stage1_libc.toStage2();
    const c_out_stream = std.io.cOutStream(output_file);
    libc.render(c_out_stream) catch |err| switch (err) {
        error.WouldBlock => unreachable, // stage1 opens stuff in exclusively blocking mode
        error.SystemResources => return .SystemResources,
        error.OperationAborted => return .OperationAborted,
        error.BrokenPipe => return .BrokenPipe,
        error.DiskQuota => return .DiskQuota,
        error.FileTooBig => return .FileTooBig,
        error.NoSpaceLeft => return .NoSpaceLeft,
        error.AccessDenied => return .AccessDenied,
        error.Unexpected => return .Unexpected,
        error.InputOutput => return .FileSystem,
    };
    return .None;
}

// ABI warning
const Stage2Target = extern struct {
    arch: c_int,
    vendor: c_int,

    abi: c_int,
    os: c_int,

    is_native_os: bool,
    is_native_cpu: bool,

    glibc_or_darwin_version: ?*Stage2SemVer,

    llvm_cpu_name: ?[*:0]const u8,
    llvm_cpu_features: ?[*:0]const u8,
    cpu_builtin_str: ?[*:0]const u8,
    cache_hash: ?[*:0]const u8,
    cache_hash_len: usize,
    os_builtin_str: ?[*:0]const u8,

    dynamic_linker: ?[*:0]const u8,
    standard_dynamic_linker_path: ?[*:0]const u8,

    llvm_cpu_features_asm_ptr: [*]const [*:0]const u8,
    llvm_cpu_features_asm_len: usize,

    fn fromTarget(self: *Stage2Target, cross_target: CrossTarget) !void {
        const allocator = std.heap.c_allocator;

        var dynamic_linker: ?[*:0]u8 = null;
        const target = try crossTargetToTarget(cross_target, &dynamic_linker);

        var cache_hash = try std.ArrayListSentineled(u8, 0).allocPrint(allocator, "{}\n{}\n", .{
            target.cpu.model.name,
            target.cpu.features.asBytes(),
        });
        defer cache_hash.deinit();

        const generic_arch_name = target.cpu.arch.genericName();
        var cpu_builtin_str_buffer = try std.ArrayListSentineled(u8, 0).allocPrint(allocator,
            \\Cpu{{
            \\    .arch = .{},
            \\    .model = &Target.{}.cpu.{},
            \\    .features = Target.{}.featureSet(&[_]Target.{}.Feature{{
            \\
        , .{
            @tagName(target.cpu.arch),
            generic_arch_name,
            target.cpu.model.name,
            generic_arch_name,
            generic_arch_name,
        });
        defer cpu_builtin_str_buffer.deinit();

        var llvm_features_buffer = try std.ArrayListSentineled(u8, 0).initSize(allocator, 0);
        defer llvm_features_buffer.deinit();

        // Unfortunately we have to do the work twice, because Clang does not support
        // the same command line parameters for CPU features when assembling code as it does
        // when compiling C code.
        var asm_features_list = std.ArrayList([*:0]const u8).init(allocator);
        defer asm_features_list.deinit();

        for (target.cpu.arch.allFeaturesList()) |feature, index_usize| {
            const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
            const is_enabled = target.cpu.features.isEnabled(index);

            if (feature.llvm_name) |llvm_name| {
                const plus_or_minus = "-+"[@boolToInt(is_enabled)];
                try llvm_features_buffer.append(plus_or_minus);
                try llvm_features_buffer.appendSlice(llvm_name);
                try llvm_features_buffer.appendSlice(",");
            }

            if (is_enabled) {
                // TODO some kind of "zig identifier escape" function rather than
                // unconditionally using @"" syntax
                try cpu_builtin_str_buffer.appendSlice("        .@\"");
                try cpu_builtin_str_buffer.appendSlice(feature.name);
                try cpu_builtin_str_buffer.appendSlice("\",\n");
            }
        }

        switch (target.cpu.arch) {
            .riscv32, .riscv64 => {
                if (std.Target.riscv.featureSetHas(target.cpu.features, .relax)) {
                    try asm_features_list.append("-mrelax");
                } else {
                    try asm_features_list.append("-mno-relax");
                }
            },
            else => {
                // TODO
                // Argh, why doesn't the assembler accept the list of CPU features?!
                // I don't see a way to do this other than hard coding everything.
            },
        }

        try cpu_builtin_str_buffer.appendSlice(
            \\    }),
            \\};
            \\
        );

        assert(mem.endsWith(u8, llvm_features_buffer.span(), ","));
        llvm_features_buffer.shrink(llvm_features_buffer.len() - 1);

        var os_builtin_str_buffer = try std.ArrayListSentineled(u8, 0).allocPrint(allocator,
            \\Os{{
            \\    .tag = .{},
            \\    .version_range = .{{
        , .{@tagName(target.os.tag)});
        defer os_builtin_str_buffer.deinit();

        // We'll re-use the OS version range builtin string for the cache hash.
        const os_builtin_str_ver_start_index = os_builtin_str_buffer.len();

        @setEvalBranchQuota(2000);
        switch (target.os.tag) {
            .freestanding,
            .ananas,
            .cloudabi,
            .dragonfly,
            .fuchsia,
            .ios,
            .kfreebsd,
            .lv2,
            .solaris,
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .cnk,
            .aix,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .elfiamcu,
            .tvos,
            .watchos,
            .mesa3d,
            .contiki,
            .amdpal,
            .hermit,
            .hurd,
            .wasi,
            .emscripten,
            .uefi,
            .other,
            => try os_builtin_str_buffer.appendSlice(" .none = {} }\n"),

            .freebsd,
            .macosx,
            .netbsd,
            .openbsd,
            => try os_builtin_str_buffer.outStream().print(
                \\ .semver = .{{
                \\        .min = .{{
                \\            .major = {},
                \\            .minor = {},
                \\            .patch = {},
                \\        }},
                \\        .max = .{{
                \\            .major = {},
                \\            .minor = {},
                \\            .patch = {},
                \\        }},
                \\    }}}},
                \\
            , .{
                target.os.version_range.semver.min.major,
                target.os.version_range.semver.min.minor,
                target.os.version_range.semver.min.patch,

                target.os.version_range.semver.max.major,
                target.os.version_range.semver.max.minor,
                target.os.version_range.semver.max.patch,
            }),

            .linux => try os_builtin_str_buffer.outStream().print(
                \\ .linux = .{{
                \\        .range = .{{
                \\            .min = .{{
                \\                .major = {},
                \\                .minor = {},
                \\                .patch = {},
                \\            }},
                \\            .max = .{{
                \\                .major = {},
                \\                .minor = {},
                \\                .patch = {},
                \\            }},
                \\        }},
                \\        .glibc = .{{
                \\            .major = {},
                \\            .minor = {},
                \\            .patch = {},
                \\        }},
                \\    }}}},
                \\
            , .{
                target.os.version_range.linux.range.min.major,
                target.os.version_range.linux.range.min.minor,
                target.os.version_range.linux.range.min.patch,

                target.os.version_range.linux.range.max.major,
                target.os.version_range.linux.range.max.minor,
                target.os.version_range.linux.range.max.patch,

                target.os.version_range.linux.glibc.major,
                target.os.version_range.linux.glibc.minor,
                target.os.version_range.linux.glibc.patch,
            }),

            .windows => try os_builtin_str_buffer.outStream().print(
                \\ .windows = .{{
                \\        .min = {s},
                \\        .max = {s},
                \\    }}}},
                \\
            , .{
                target.os.version_range.windows.min,
                target.os.version_range.windows.max,
            }),
        }
        try os_builtin_str_buffer.appendSlice("};\n");

        try cache_hash.appendSlice(
            os_builtin_str_buffer.span()[os_builtin_str_ver_start_index..os_builtin_str_buffer.len()],
        );

        const glibc_or_darwin_version = blk: {
            if (target.isGnuLibC()) {
                const stage1_glibc = try std.heap.c_allocator.create(Stage2SemVer);
                const stage2_glibc = target.os.version_range.linux.glibc;
                stage1_glibc.* = .{
                    .major = stage2_glibc.major,
                    .minor = stage2_glibc.minor,
                    .patch = stage2_glibc.patch,
                };
                break :blk stage1_glibc;
            } else if (target.isDarwin()) {
                const stage1_semver = try std.heap.c_allocator.create(Stage2SemVer);
                const stage2_semver = target.os.version_range.semver.min;
                stage1_semver.* = .{
                    .major = stage2_semver.major,
                    .minor = stage2_semver.minor,
                    .patch = stage2_semver.patch,
                };
                break :blk stage1_semver;
            } else {
                break :blk null;
            }
        };

        const std_dl = target.standardDynamicLinkerPath();
        const std_dl_z = if (std_dl.get()) |dl|
            (try mem.dupeZ(std.heap.c_allocator, u8, dl)).ptr
        else
            null;

        const cache_hash_slice = cache_hash.toOwnedSlice();
        const asm_features = asm_features_list.toOwnedSlice();
        self.* = .{
            .arch = @enumToInt(target.cpu.arch) + 1, // skip over ZigLLVM_UnknownArch
            .vendor = 0,
            .os = @enumToInt(target.os.tag),
            .abi = @enumToInt(target.abi),
            .llvm_cpu_name = if (target.cpu.model.llvm_name) |s| s.ptr else null,
            .llvm_cpu_features = llvm_features_buffer.toOwnedSlice().ptr,
            .llvm_cpu_features_asm_ptr = asm_features.ptr,
            .llvm_cpu_features_asm_len = asm_features.len,
            .cpu_builtin_str = cpu_builtin_str_buffer.toOwnedSlice().ptr,
            .os_builtin_str = os_builtin_str_buffer.toOwnedSlice().ptr,
            .cache_hash = cache_hash_slice.ptr,
            .cache_hash_len = cache_hash_slice.len,
            .is_native_os = cross_target.isNativeOs(),
            .is_native_cpu = cross_target.isNativeCpu(),
            .glibc_or_darwin_version = glibc_or_darwin_version,
            .dynamic_linker = dynamic_linker,
            .standard_dynamic_linker_path = std_dl_z,
        };
    }
};

fn enumInt(comptime Enum: type, int: c_int) Enum {
    return @intToEnum(Enum, @intCast(@TagType(Enum), int));
}

fn crossTargetToTarget(cross_target: CrossTarget, dynamic_linker_ptr: *?[*:0]u8) !Target {
    var info = try std.zig.system.NativeTargetInfo.detect(std.heap.c_allocator, cross_target);
    if (info.cpu_detection_unimplemented) {
        // TODO We want to just use detected_info.target but implementing
        // CPU model & feature detection is todo so here we rely on LLVM.
        const llvm = @import("llvm.zig");
        const llvm_cpu_name = llvm.GetHostCPUName();
        const llvm_cpu_features = llvm.GetNativeFeatures();
        const arch = std.Target.current.cpu.arch;
        info.target.cpu = try detectNativeCpuWithLLVM(arch, llvm_cpu_name, llvm_cpu_features);
        cross_target.updateCpuFeatures(&info.target.cpu.features);
        info.target.cpu.arch = cross_target.getCpuArch();
    }
    if (info.dynamic_linker.get()) |dl| {
        dynamic_linker_ptr.* = try mem.dupeZ(std.heap.c_allocator, u8, dl);
    } else {
        dynamic_linker_ptr.* = null;
    }
    return info.target;
}

// ABI warning
const Stage2SemVer = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
};

// ABI warning
const Stage2NativePaths = extern struct {
    include_dirs_ptr: [*][*:0]u8,
    include_dirs_len: usize,
    lib_dirs_ptr: [*][*:0]u8,
    lib_dirs_len: usize,
    rpaths_ptr: [*][*:0]u8,
    rpaths_len: usize,
    warnings_ptr: [*][*:0]u8,
    warnings_len: usize,
};
// ABI warning
export fn stage2_detect_native_paths(stage1_paths: *Stage2NativePaths) Error {
    stage2DetectNativePaths(stage1_paths) catch |err| switch (err) {
        error.OutOfMemory => return .OutOfMemory,
    };
    return .None;
}

fn stage2DetectNativePaths(stage1_paths: *Stage2NativePaths) !void {
    var paths = try std.zig.system.NativePaths.detect(std.heap.c_allocator);
    errdefer paths.deinit();

    try convertSlice(paths.include_dirs.span(), &stage1_paths.include_dirs_ptr, &stage1_paths.include_dirs_len);
    try convertSlice(paths.lib_dirs.span(), &stage1_paths.lib_dirs_ptr, &stage1_paths.lib_dirs_len);
    try convertSlice(paths.rpaths.span(), &stage1_paths.rpaths_ptr, &stage1_paths.rpaths_len);
    try convertSlice(paths.warnings.span(), &stage1_paths.warnings_ptr, &stage1_paths.warnings_len);
}

fn convertSlice(slice: [][:0]u8, ptr: *[*][*:0]u8, len: *usize) !void {
    len.* = slice.len;
    const new_slice = try std.heap.c_allocator.alloc([*:0]u8, slice.len);
    for (slice) |item, i| {
        new_slice[i] = item.ptr;
    }
    ptr.* = new_slice.ptr;
}

const clang_args = @import("clang_options.zig").list;

// ABI warning
pub const ClangArgIterator = extern struct {
    has_next: bool,
    zig_equivalent: ZigEquivalent,
    only_arg: [*:0]const u8,
    second_arg: [*:0]const u8,
    other_args_ptr: [*]const [*:0]const u8,
    other_args_len: usize,
    argv_ptr: [*]const [*:0]const u8,
    argv_len: usize,
    next_index: usize,
    root_args: ?*Args,

    // ABI warning
    pub const ZigEquivalent = extern enum {
        target,
        o,
        c,
        other,
        positional,
        l,
        ignore,
        driver_punt,
        pic,
        no_pic,
        nostdlib,
        nostdlib_cpp,
        shared,
        rdynamic,
        wl,
        pp_or_asm,
        optimize,
        debug,
        sanitize,
        linker_script,
        verbose_cmds,
        for_linker,
        linker_input_z,
        lib_dir,
        mcpu,
        dep_file,
        framework_dir,
        framework,
        nostdlibinc,
    };

    const Args = struct {
        next_index: usize,
        argv_ptr: [*]const [*:0]const u8,
        argv_len: usize,
    };

    pub fn init(argv: []const [*:0]const u8) ClangArgIterator {
        return .{
            .next_index = 2, // `zig cc foo` this points to `foo`
            .has_next = argv.len > 2,
            .zig_equivalent = undefined,
            .only_arg = undefined,
            .second_arg = undefined,
            .other_args_ptr = undefined,
            .other_args_len = undefined,
            .argv_ptr = argv.ptr,
            .argv_len = argv.len,
            .root_args = null,
        };
    }

    pub fn next(self: *ClangArgIterator) !void {
        assert(self.has_next);
        assert(self.next_index < self.argv_len);
        // In this state we know that the parameter we are looking at is a root parameter
        // rather than an argument to a parameter.
        self.other_args_ptr = self.argv_ptr + self.next_index;
        self.other_args_len = 1; // We adjust this value below when necessary.
        var arg = mem.span(self.argv_ptr[self.next_index]);
        self.incrementArgIndex();

        if (mem.startsWith(u8, arg, "@")) {
            if (self.root_args != null) return error.NestedResponseFile;

            // This is a "compiler response file". We must parse the file and treat its
            // contents as command line parameters.
            const allocator = std.heap.c_allocator;
            const max_bytes = 10 * 1024 * 1024; // 10 MiB of command line arguments is a reasonable limit
            const resp_file_path = arg[1..];
            const resp_contents = fs.cwd().readFileAlloc(allocator, resp_file_path, max_bytes) catch |err| {
                std.debug.warn("unable to read response file '{}': {}\n", .{ resp_file_path, @errorName(err) });
                process.exit(1);
            };
            defer allocator.free(resp_contents);
            // TODO is there a specification for this file format? Let's find it and make this parsing more robust
            // at the very least I'm guessing this needs to handle quotes and `#` comments.
            var it = mem.tokenize(resp_contents, " \t\r\n");
            var resp_arg_list = std.ArrayList([*:0]const u8).init(allocator);
            defer resp_arg_list.deinit();
            {
                errdefer {
                    for (resp_arg_list.span()) |item| {
                        allocator.free(mem.span(item));
                    }
                }
                while (it.next()) |token| {
                    const dupe_token = try mem.dupeZ(allocator, u8, token);
                    errdefer allocator.free(dupe_token);
                    try resp_arg_list.append(dupe_token);
                }
                const args = try allocator.create(Args);
                errdefer allocator.destroy(args);
                args.* = .{
                    .next_index = self.next_index,
                    .argv_ptr = self.argv_ptr,
                    .argv_len = self.argv_len,
                };
                self.root_args = args;
            }
            const resp_arg_slice = resp_arg_list.toOwnedSlice();
            self.next_index = 0;
            self.argv_ptr = resp_arg_slice.ptr;
            self.argv_len = resp_arg_slice.len;

            if (resp_arg_slice.len == 0) {
                self.resolveRespFileArgs();
                return;
            }

            self.has_next = true;
            self.other_args_ptr = self.argv_ptr + self.next_index;
            self.other_args_len = 1; // We adjust this value below when necessary.
            arg = mem.span(self.argv_ptr[self.next_index]);
            self.incrementArgIndex();
        }
        if (!mem.startsWith(u8, arg, "-")) {
            self.zig_equivalent = .positional;
            self.only_arg = arg.ptr;
            return;
        }

        find_clang_arg: for (clang_args) |clang_arg| switch (clang_arg.syntax) {
            .flag => {
                const prefix_len = clang_arg.matchEql(arg);
                if (prefix_len > 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg.ptr + prefix_len;

                    break :find_clang_arg;
                }
            },
            .joined, .comma_joined => {
                // joined example: --target=foo
                // comma_joined example: -Wl,-soname,libsoundio.so.2
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg.ptr + prefix_len; // This will skip over the "--target=" part.

                    break :find_clang_arg;
                }
            },
            .joined_or_separate => {
                // Examples: `-lfoo`, `-l foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len == arg.len) {
                    if (self.next_index >= self.argv_len) {
                        std.debug.warn("Expected parameter after '{}'\n", .{arg});
                        process.exit(1);
                    }
                    self.only_arg = self.argv_ptr[self.next_index];
                    self.incrementArgIndex();
                    self.other_args_len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;

                    break :find_clang_arg;
                } else if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg.ptr + prefix_len;

                    break :find_clang_arg;
                }
            },
            .joined_and_separate => {
                // Example: `-Xopenmp-target=riscv64-linux-unknown foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.only_arg = arg.ptr + prefix_len;
                    if (self.next_index >= self.argv_len) {
                        std.debug.warn("Expected parameter after '{}'\n", .{arg});
                        process.exit(1);
                    }
                    self.second_arg = self.argv_ptr[self.next_index];
                    self.incrementArgIndex();
                    self.other_args_len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    break :find_clang_arg;
                }
            },
            .separate => if (clang_arg.matchEql(arg) > 0) {
                if (self.next_index >= self.argv_len) {
                    std.debug.warn("Expected parameter after '{}'\n", .{arg});
                    process.exit(1);
                }
                self.only_arg = self.argv_ptr[self.next_index];
                self.incrementArgIndex();
                self.other_args_len += 1;
                self.zig_equivalent = clang_arg.zig_equivalent;
                break :find_clang_arg;
            },
            .remaining_args_joined => {
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    @panic("TODO");
                }
            },
            .multi_arg => if (clang_arg.matchEql(arg) > 0) {
                @panic("TODO");
            },
        }
        else {
            std.debug.warn("Unknown Clang option: '{}'\n", .{arg});
            process.exit(1);
        }
    }

    fn incrementArgIndex(self: *ClangArgIterator) void {
        self.next_index += 1;
        self.resolveRespFileArgs();
    }

    fn resolveRespFileArgs(self: *ClangArgIterator) void {
        const allocator = std.heap.c_allocator;
        if (self.next_index >= self.argv_len) {
            if (self.root_args) |root_args| {
                self.next_index = root_args.next_index;
                self.argv_ptr = root_args.argv_ptr;
                self.argv_len = root_args.argv_len;

                allocator.destroy(root_args);
                self.root_args = null;
            }
            if (self.next_index >= self.argv_len) {
                self.has_next = false;
            }
        }
    }
};

export fn stage2_clang_arg_iterator(
    result: *ClangArgIterator,
    argc: usize,
    argv: [*]const [*:0]const u8,
) void {
    result.* = ClangArgIterator.init(argv[0..argc]);
}

export fn stage2_clang_arg_next(it: *ClangArgIterator) Error {
    it.next() catch |err| switch (err) {
        error.NestedResponseFile => return .NestedResponseFile,
        error.OutOfMemory => return .OutOfMemory,
    };
    return .None;
}

export const stage2_is_zig0 = false;
