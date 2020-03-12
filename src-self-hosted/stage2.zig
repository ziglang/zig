// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.

const std = @import("std");
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const self_hosted_main = @import("main.zig");
const errmsg = @import("errmsg.zig");
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
    var errors = @as([*]translate_c.ClangErrMsg, undefined)[0..0];
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

// TODO: just use the actual self-hosted zig fmt. Until https://github.com/ziglang/zig/issues/2377,
// we use a blocking implementation.
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
        try args_list.append(mem.toSliceConst(u8, argv[arg_i]));
    }

    stdout = std.io.getStdOut().outStream();
    stderr_file = std.io.getStdErr();
    stderr = stderr_file.outStream();

    const args = args_list.toSliceConst()[2..];

    var color: errmsg.Color = .Auto;
    var stdin_flag: bool = false;
    var check_flag: bool = false;
    var input_files = ArrayList([]const u8).init(allocator);

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "--help")) {
                    try stdout.writeAll(self_hosted_main.usage_fmt);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        try stderr.writeAll("expected [auto|on|off] after --color\n");
                        process.exit(1);
                    }
                    i += 1;
                    const next_arg = args[i];
                    if (mem.eql(u8, next_arg, "auto")) {
                        color = .Auto;
                    } else if (mem.eql(u8, next_arg, "on")) {
                        color = .On;
                    } else if (mem.eql(u8, next_arg, "off")) {
                        color = .Off;
                    } else {
                        try stderr.print("expected [auto|on|off] after --color, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--stdin")) {
                    stdin_flag = true;
                } else if (mem.eql(u8, arg, "--check")) {
                    check_flag = true;
                } else {
                    try stderr.print("unrecognized parameter: '{}'", .{arg});
                    process.exit(1);
                }
            } else {
                try input_files.append(arg);
            }
        }
    }

    if (stdin_flag) {
        if (input_files.len != 0) {
            try stderr.writeAll("cannot use --stdin with positional arguments\n");
            process.exit(1);
        }

        const stdin_file = io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.readAllAlloc(allocator, self_hosted_main.max_src_size);
        defer allocator.free(source_code);

        const tree = std.zig.parse(allocator, source_code) catch |err| {
            try stderr.print("error parsing stdin: {}\n", .{err});
            process.exit(1);
        };
        defer tree.deinit();

        var error_it = tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            try printErrMsgToFile(allocator, parse_error, tree, "<stdin>", stderr_file, color);
        }
        if (tree.errors.len != 0) {
            process.exit(1);
        }
        if (check_flag) {
            const anything_changed = try std.zig.render(allocator, io.null_out_stream, tree);
            const code = if (anything_changed) @as(u8, 1) else @as(u8, 0);
            process.exit(code);
        }

        _ = try std.zig.render(allocator, stdout, tree);
        return;
    }

    if (input_files.len == 0) {
        try stderr.writeAll("expected at least one source file argument\n");
        process.exit(1);
    }

    var fmt = Fmt{
        .seen = Fmt.SeenMap.init(allocator),
        .any_error = false,
        .color = color,
        .allocator = allocator,
    };

    for (input_files.toSliceConst()) |file_path| {
        try fmtPath(&fmt, file_path, check_flag);
    }
    if (fmt.any_error) {
        process.exit(1);
    }
}

const FmtError = error{
    SystemResources,
    OperationAborted,
    IoPending,
    BrokenPipe,
    Unexpected,
    WouldBlock,
    FileClosed,
    DestinationAddressRequired,
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    AccessDenied,
    OutOfMemory,
    RenameAcrossMountPoints,
    ReadOnlyFileSystem,
    LinkQuotaExceeded,
    FileBusy,
} || fs.File.OpenError;

fn fmtPath(fmt: *Fmt, file_path: []const u8, check_mode: bool) FmtError!void {
    if (fmt.seen.exists(file_path)) return;
    try fmt.seen.put(file_path);

    const source_code = io.readFileAlloc(fmt.allocator, file_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => {
            // TODO make event based (and dir.next())
            var dir = try fs.cwd().openDirList(file_path);
            defer dir.close();

            var dir_it = dir.iterate();

            while (try dir_it.next()) |entry| {
                if (entry.kind == .Directory or mem.endsWith(u8, entry.name, ".zig")) {
                    const full_path = try fs.path.join(fmt.allocator, &[_][]const u8{ file_path, entry.name });
                    try fmtPath(fmt, full_path, check_mode);
                }
            }
            return;
        },
        else => {
            // TODO lock stderr printing
            try stderr.print("unable to open '{}': {}\n", .{ file_path, err });
            fmt.any_error = true;
            return;
        },
    };
    defer fmt.allocator.free(source_code);

    const tree = std.zig.parse(fmt.allocator, source_code) catch |err| {
        try stderr.print("error parsing file '{}': {}\n", .{ file_path, err });
        fmt.any_error = true;
        return;
    };
    defer tree.deinit();

    var error_it = tree.errors.iterator(0);
    while (error_it.next()) |parse_error| {
        try printErrMsgToFile(fmt.allocator, parse_error, tree, file_path, stderr_file, fmt.color);
    }
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (check_mode) {
        const anything_changed = try std.zig.render(fmt.allocator, io.null_out_stream, tree);
        if (anything_changed) {
            try stderr.print("{}\n", .{file_path});
            fmt.any_error = true;
        }
    } else {
        const baf = try io.BufferedAtomicFile.create(fmt.allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(fmt.allocator, baf.stream(), tree);
        if (anything_changed) {
            try stderr.print("{}\n", .{file_path});
            try baf.finish();
        }
    }
}

const Fmt = struct {
    seen: SeenMap,
    any_error: bool,
    color: errmsg.Color,
    allocator: *mem.Allocator,

    const SeenMap = std.BufSet;
};

fn printErrMsgToFile(
    allocator: *mem.Allocator,
    parse_error: *const ast.Error,
    tree: *ast.Tree,
    path: []const u8,
    file: fs.File,
    color: errmsg.Color,
) !void {
    const color_on = switch (color) {
        .Auto => file.isTty(),
        .On => true,
        .Off => false,
    };
    const lok_token = parse_error.loc();
    const span = errmsg.Span{
        .first = lok_token,
        .last = lok_token,
    };

    const first_token = tree.tokens.at(span.first);
    const last_token = tree.tokens.at(span.last);
    const start_loc = tree.tokenLocationPtr(0, first_token);
    const end_loc = tree.tokenLocationPtr(first_token.end, last_token);

    var text_buf = try std.Buffer.initSize(allocator, 0);
    const out_stream = &text_buf.outStream();
    try parse_error.render(&tree.tokens, out_stream);
    const text = text_buf.toOwnedSlice();

    const stream = &file.outStream();
    try stream.print("{}:{}:{}: error: {}\n", .{ path, start_loc.line + 1, start_loc.column + 1, text });

    if (!color_on) return;

    // Print \r and \t as one space each so that column counts line up
    for (tree.source[start_loc.line_start..start_loc.line_end]) |byte| {
        try stream.writeByte(switch (byte) {
            '\r', '\t' => ' ',
            else => byte,
        });
    }
    try stream.writeByte('\n');
    try stream.writeByteNTimes(' ', start_loc.column);
    try stream.writeByteNTimes('~', last_token.end - first_token.start);
    try stream.writeByte('\n');
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
        const textz = std.Buffer.init(&self.handle.arena.allocator, self.handle.error_text) catch @panic("failed to create .d tokenizer error text");
        return stage2_DepNextResult{
            .type_id = .error_,
            .textz = textz.toSlice().ptr,
        };
    };
    const token = otoken orelse {
        return stage2_DepNextResult{
            .type_id = .null_,
            .textz = undefined,
        };
    };
    const textz = std.Buffer.init(&self.handle.arena.allocator, token.bytes) catch @panic("failed to create .d tokenizer token text");
    return stage2_DepNextResult{
        .type_id = switch (token.id) {
            .target => .target,
            .prereq => .prereq,
        },
        .textz = textz.toSlice().ptr,
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
        const llvm_cpu_name = mem.toSliceConst(u8, cpu_name_z);

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
        var it = mem.tokenize(mem.toSliceConst(u8, llvm_cpu_features), ",");
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
    const zig_triple = if (zig_triple_oz) |zig_triple_z| mem.toSliceConst(u8, zig_triple_z) else "native";
    const mcpu = if (mcpu_oz) |mcpu_z| mem.toSliceConst(u8, mcpu_z) else null;
    const dynamic_linker = if (dynamic_linker_oz) |dl_z| mem.toSliceConst(u8, dl_z) else null;
    var diags: CrossTarget.ParseOptions.Diagnostics = .{};
    const target: CrossTarget = CrossTarget.parse(.{
        .arch_os_abi = zig_triple,
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
    include_dir: [*:0]const u8,
    include_dir_len: usize,
    sys_include_dir: [*:0]const u8,
    sys_include_dir_len: usize,
    crt_dir: [*:0]const u8,
    crt_dir_len: usize,
    msvc_lib_dir: [*:0]const u8,
    msvc_lib_dir_len: usize,
    kernel32_lib_dir: [*:0]const u8,
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
            libc.include_dir = self.include_dir[0..self.include_dir_len :0];
        }
        if (self.sys_include_dir_len != 0) {
            libc.sys_include_dir = self.sys_include_dir[0..self.sys_include_dir_len :0];
        }
        if (self.crt_dir_len != 0) {
            libc.crt_dir = self.crt_dir[0..self.crt_dir_len :0];
        }
        if (self.msvc_lib_dir_len != 0) {
            libc.msvc_lib_dir = self.msvc_lib_dir[0..self.msvc_lib_dir_len :0];
        }
        if (self.kernel32_lib_dir_len != 0) {
            libc.kernel32_lib_dir = self.kernel32_lib_dir[0..self.kernel32_lib_dir_len :0];
        }
        return libc;
    }
};

// ABI warning
export fn stage2_libc_parse(stage1_libc: *Stage2LibCInstallation, libc_file_z: [*:0]const u8) Error {
    stderr_file = std.io.getStdErr();
    stderr = stderr_file.outStream();
    const libc_file = mem.toSliceConst(u8, libc_file_z);
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

    is_native: bool,

    glibc_or_darwin_version: ?*Stage2SemVer,

    llvm_cpu_name: ?[*:0]const u8,
    llvm_cpu_features: ?[*:0]const u8,
    cpu_builtin_str: ?[*:0]const u8,
    cache_hash: ?[*:0]const u8,
    cache_hash_len: usize,
    os_builtin_str: ?[*:0]const u8,

    dynamic_linker: ?[*:0]const u8,

    fn fromTarget(self: *Stage2Target, cross_target: CrossTarget) !void {
        const allocator = std.heap.c_allocator;

        var dynamic_linker: ?[*:0]u8 = null;
        const target = try crossTargetToTarget(cross_target, &dynamic_linker);

        var cache_hash = try std.Buffer.allocPrint(allocator, "{}\n{}\n", .{
            target.cpu.model.name,
            target.cpu.features.asBytes(),
        });
        defer cache_hash.deinit();

        const generic_arch_name = target.cpu.arch.genericName();
        var cpu_builtin_str_buffer = try std.Buffer.allocPrint(allocator,
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

        var llvm_features_buffer = try std.Buffer.initSize(allocator, 0);
        defer llvm_features_buffer.deinit();

        for (target.cpu.arch.allFeaturesList()) |feature, index_usize| {
            const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
            const is_enabled = target.cpu.features.isEnabled(index);

            if (feature.llvm_name) |llvm_name| {
                const plus_or_minus = "-+"[@boolToInt(is_enabled)];
                try llvm_features_buffer.appendByte(plus_or_minus);
                try llvm_features_buffer.append(llvm_name);
                try llvm_features_buffer.append(",");
            }

            if (is_enabled) {
                // TODO some kind of "zig identifier escape" function rather than
                // unconditionally using @"" syntax
                try cpu_builtin_str_buffer.append("        .@\"");
                try cpu_builtin_str_buffer.append(feature.name);
                try cpu_builtin_str_buffer.append("\",\n");
            }
        }

        try cpu_builtin_str_buffer.append(
            \\    }),
            \\};
            \\
        );

        assert(mem.endsWith(u8, llvm_features_buffer.toSliceConst(), ","));
        llvm_features_buffer.shrink(llvm_features_buffer.len() - 1);

        var os_builtin_str_buffer = try std.Buffer.allocPrint(allocator,
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
            => try os_builtin_str_buffer.append(" .none = {} }\n"),

            .freebsd,
            .macosx,
            .netbsd,
            .openbsd,
            => try os_builtin_str_buffer.print(
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

            .linux => try os_builtin_str_buffer.print(
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

            .windows => try os_builtin_str_buffer.print(
                \\ .windows = .{{
                \\        .min = .{},
                \\        .max = .{},
                \\    }}}},
                \\
            , .{
                @tagName(target.os.version_range.windows.min),
                @tagName(target.os.version_range.windows.max),
            }),
        }
        try os_builtin_str_buffer.append("};\n");

        try cache_hash.append(
            os_builtin_str_buffer.toSlice()[os_builtin_str_ver_start_index..os_builtin_str_buffer.len()],
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

        const cache_hash_slice = cache_hash.toOwnedSlice();
        self.* = .{
            .arch = @enumToInt(target.cpu.arch) + 1, // skip over ZigLLVM_UnknownArch
            .vendor = 0,
            .os = @enumToInt(target.os.tag),
            .abi = @enumToInt(target.abi),
            .llvm_cpu_name = if (target.cpu.model.llvm_name) |s| s.ptr else null,
            .llvm_cpu_features = llvm_features_buffer.toOwnedSlice().ptr,
            .cpu_builtin_str = cpu_builtin_str_buffer.toOwnedSlice().ptr,
            .os_builtin_str = os_builtin_str_buffer.toOwnedSlice().ptr,
            .cache_hash = cache_hash_slice.ptr,
            .cache_hash_len = cache_hash_slice.len,
            .is_native = cross_target.isNative(),
            .glibc_or_darwin_version = glibc_or_darwin_version,
            .dynamic_linker = dynamic_linker,
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

    try convertSlice(paths.include_dirs.toSlice(), &stage1_paths.include_dirs_ptr, &stage1_paths.include_dirs_len);
    try convertSlice(paths.lib_dirs.toSlice(), &stage1_paths.lib_dirs_ptr, &stage1_paths.lib_dirs_len);
    try convertSlice(paths.rpaths.toSlice(), &stage1_paths.rpaths_ptr, &stage1_paths.rpaths_len);
    try convertSlice(paths.warnings.toSlice(), &stage1_paths.warnings_ptr, &stage1_paths.warnings_len);
}

fn convertSlice(slice: [][:0]u8, ptr: *[*][*:0]u8, len: *usize) !void {
    len.* = slice.len;
    const new_slice = try std.heap.c_allocator.alloc([*:0]u8, slice.len);
    for (slice) |item, i| {
        new_slice[i] = item.ptr;
    }
    ptr.* = new_slice.ptr;
}
