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
const self_hosted_main = @import("main.zig");
const errmsg = @import("errmsg.zig");
const DepTokenizer = @import("dep_tokenizer.zig").Tokenizer;
const assert = std.debug.assert;

var stderr_file: fs.File = undefined;
var stderr: *io.OutStream(fs.File.WriteError) = undefined;
var stdout: *io.OutStream(fs.File.WriteError) = undefined;

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
    UnknownCpu,
    UnknownSubArchitecture,
    UnknownCpuFeature,
    InvalidCpuFeatures,
    InvalidLlvmCpuFeaturesFormat,
    UnknownApplicationBinaryInterface,
    ASTUnitFailure,
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
            return Error.CCompileErrors;
        },
        error.ASTUnitFailure => return Error.ASTUnitFailure,
        error.OutOfMemory => return Error.OutOfMemory,
    };
    return Error.None;
}

export fn stage2_free_clang_errors(errors_ptr: [*]translate_c.ClangErrMsg, errors_len: usize) void {
    translate_c.freeErrors(errors_ptr[0..errors_len]);
}

export fn stage2_render_ast(tree: *ast.Tree, output_file: *FILE) Error {
    const c_out_stream = &std.io.COutStream.init(output_file).stream;
    _ = std.zig.render(std.heap.c_allocator, c_out_stream, tree) catch |e| switch (e) {
        error.WouldBlock => unreachable, // stage1 opens stuff in exclusively blocking mode
        error.SystemResources => return Error.SystemResources,
        error.OperationAborted => return Error.OperationAborted,
        error.BrokenPipe => return Error.BrokenPipe,
        error.DiskQuota => return Error.DiskQuota,
        error.FileTooBig => return Error.FileTooBig,
        error.NoSpaceLeft => return Error.NoSpaceLeft,
        error.AccessDenied => return Error.AccessDenied,
        error.OutOfMemory => return Error.OutOfMemory,
        error.Unexpected => return Error.Unexpected,
        error.InputOutput => return Error.FileSystem,
    };
    return Error.None;
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

    stdout = &std.io.getStdOut().outStream().stream;
    stderr_file = std.io.getStdErr();
    stderr = &stderr_file.outStream().stream;

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
                    try stdout.write(self_hosted_main.usage_fmt);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected [auto|on|off] after --color\n");
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
            try stderr.write("cannot use --stdin with positional arguments\n");
            process.exit(1);
        }

        const stdin_file = io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.stream.readAllAlloc(allocator, self_hosted_main.max_src_size);
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
        try stderr.write("expected at least one source file argument\n");
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
    var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
    try parse_error.render(&tree.tokens, out_stream);
    const text = text_buf.toOwnedSlice();

    const stream = &file.outStream().stream;
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

fn cpuFeaturesFromLLVM(
    arch: Target.Arch,
    llvm_cpu_name_z: ?[*:0]const u8,
    llvm_cpu_features_opt: ?[*:0]const u8,
) !Target.CpuFeatures {
    var result = arch.getBaselineCpuFeatures();

    if (llvm_cpu_name_z) |cpu_name_z| {
        const llvm_cpu_name = mem.toSliceConst(u8, cpu_name_z);

        for (arch.allCpus()) |cpu| {
            const this_llvm_name = cpu.llvm_name orelse continue;
            if (mem.eql(u8, this_llvm_name, llvm_cpu_name)) {
                // Here we use the non-dependencies-populated set,
                // so that subtracting features later in this function
                // affect the prepopulated set.
                result = Target.CpuFeatures{
                    .cpu = cpu,
                    .features = cpu.features,
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
export fn stage2_cmd_targets(zig_triple: [*:0]const u8) c_int {
    cmdTargets(zig_triple) catch |err| {
        std.debug.warn("unable to list targets: {}\n", .{@errorName(err)});
        return -1;
    };
    return 0;
}

fn cmdTargets(zig_triple: [*:0]const u8) !void {
    var target = try Target.parse(mem.toSliceConst(u8, zig_triple));
    target.Cross.cpu_features = blk: {
        const llvm = @import("llvm.zig");
        const llvm_cpu_name = llvm.GetHostCPUName();
        const llvm_cpu_features = llvm.GetNativeFeatures();
        break :blk try cpuFeaturesFromLLVM(target.Cross.arch, llvm_cpu_name, llvm_cpu_features);
    };
    return @import("print_targets.zig").cmdTargets(
        std.heap.c_allocator,
        &[0][]u8{},
        &std.io.getStdOut().outStream().stream,
        target,
    );
}

const Stage2CpuFeatures = struct {
    allocator: *mem.Allocator,
    cpu_features: Target.CpuFeatures,

    llvm_features_str: ?[*:0]const u8,

    builtin_str: [:0]const u8,
    cache_hash: [:0]const u8,

    const Self = @This();

    fn createFromNative(allocator: *mem.Allocator) !*Self {
        const arch = Target.current.getArch();
        const llvm = @import("llvm.zig");
        const llvm_cpu_name = llvm.GetHostCPUName();
        const llvm_cpu_features = llvm.GetNativeFeatures();
        const cpu_features = try cpuFeaturesFromLLVM(arch, llvm_cpu_name, llvm_cpu_features);
        return createFromCpuFeatures(allocator, arch, cpu_features);
    }

    fn createFromCpuFeatures(
        allocator: *mem.Allocator,
        arch: Target.Arch,
        cpu_features: Target.CpuFeatures,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const cache_hash = try std.fmt.allocPrint0(allocator, "{}\n{}", .{
            cpu_features.cpu.name,
            cpu_features.features.asBytes(),
        });
        errdefer allocator.free(cache_hash);

        const generic_arch_name = arch.genericName();
        var builtin_str_buffer = try std.Buffer.allocPrint(allocator,
            \\CpuFeatures{{
            \\    .cpu = &Target.{}.cpu.{},
            \\    .features = Target.{}.featureSet(&[_]Target.{}.Feature{{
            \\
        , .{
            generic_arch_name,
            cpu_features.cpu.name,
            generic_arch_name,
            generic_arch_name,
        });
        defer builtin_str_buffer.deinit();

        var llvm_features_buffer = try std.Buffer.initSize(allocator, 0);
        defer llvm_features_buffer.deinit();

        for (arch.allFeaturesList()) |feature, index_usize| {
            const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
            const is_enabled = cpu_features.features.isEnabled(index);

            if (feature.llvm_name) |llvm_name| {
                const plus_or_minus = "-+"[@boolToInt(is_enabled)];
                try llvm_features_buffer.appendByte(plus_or_minus);
                try llvm_features_buffer.append(llvm_name);
                try llvm_features_buffer.append(",");
            }

            if (is_enabled) {
                // TODO some kind of "zig identifier escape" function rather than
                // unconditionally using @"" syntax
                try builtin_str_buffer.append("        .@\"");
                try builtin_str_buffer.append(feature.name);
                try builtin_str_buffer.append("\",\n");
            }
        }

        try builtin_str_buffer.append(
            \\    }),
            \\};
            \\
        );

        assert(mem.endsWith(u8, llvm_features_buffer.toSliceConst(), ","));
        llvm_features_buffer.shrink(llvm_features_buffer.len() - 1);

        self.* = Self{
            .allocator = allocator,
            .cpu_features = cpu_features,
            .llvm_features_str = llvm_features_buffer.toOwnedSlice().ptr,
            .builtin_str = builtin_str_buffer.toOwnedSlice(),
            .cache_hash = cache_hash,
        };
        return self;
    }

    fn destroy(self: *Self) void {
        self.allocator.free(self.cache_hash);
        self.allocator.free(self.builtin_str);
        // TODO if (self.llvm_features_str) |llvm_features_str| self.allocator.free(llvm_features_str);
        self.allocator.destroy(self);
    }
};

// ABI warning
export fn stage2_cpu_features_parse(
    result: **Stage2CpuFeatures,
    zig_triple: ?[*:0]const u8,
    cpu_name: ?[*:0]const u8,
    cpu_features: ?[*:0]const u8,
) Error {
    result.* = stage2ParseCpuFeatures(zig_triple, cpu_name, cpu_features) catch |err| switch (err) {
        error.OutOfMemory => return .OutOfMemory,
        error.UnknownArchitecture => return .UnknownArchitecture,
        error.UnknownSubArchitecture => return .UnknownSubArchitecture,
        error.UnknownOperatingSystem => return .UnknownOperatingSystem,
        error.UnknownApplicationBinaryInterface => return .UnknownApplicationBinaryInterface,
        error.MissingOperatingSystem => return .MissingOperatingSystem,
        error.MissingArchitecture => return .MissingArchitecture,
        error.InvalidLlvmCpuFeaturesFormat => return .InvalidLlvmCpuFeaturesFormat,
        error.InvalidCpuFeatures => return .InvalidCpuFeatures,
    };
    return .None;
}

fn stage2ParseCpuFeatures(
    zig_triple_oz: ?[*:0]const u8,
    cpu_name_oz: ?[*:0]const u8,
    cpu_features_oz: ?[*:0]const u8,
) !*Stage2CpuFeatures {
    const zig_triple_z = zig_triple_oz orelse return Stage2CpuFeatures.createFromNative(std.heap.c_allocator);
    const target = try Target.parse(mem.toSliceConst(u8, zig_triple_z));
    const arch = target.Cross.arch;

    const cpu = if (cpu_name_oz) |cpu_name_z| blk: {
        const cpu_name = mem.toSliceConst(u8, cpu_name_z);
        break :blk arch.parseCpu(cpu_name) catch |err| switch (err) {
            error.UnknownCpu => {
                std.debug.warn("Unknown CPU: '{}'\nAvailable CPUs for architecture '{}':\n", .{
                    cpu_name,
                    @tagName(arch),
                });
                for (arch.allCpus()) |cpu| {
                    std.debug.warn(" {}\n", .{cpu.name});
                }
                process.exit(1);
            },
            else => |e| return e,
        };
    } else target.Cross.cpu_features.cpu;

    var set = if (cpu_features_oz) |cpu_features_z| blk: {
        const cpu_features = mem.toSliceConst(u8, cpu_features_z);
        break :blk arch.parseCpuFeatureSet(cpu, cpu_features) catch |err| switch (err) {
            error.UnknownCpuFeature => {
                std.debug.warn(
                    \\Unknown CPU features specified.
                    \\Available CPU features for architecture '{}':
                    \\
                , .{@tagName(arch)});
                for (arch.allFeaturesList()) |feature| {
                    std.debug.warn(" {}\n", .{feature.name});
                }
                process.exit(1);
            },
            else => |e| return e,
        };
    } else cpu.features;

    if (arch.subArchFeature()) |index| {
        set.addFeature(index);
    }
    set.populateDependencies(arch.allFeaturesList());

    return Stage2CpuFeatures.createFromCpuFeatures(std.heap.c_allocator, arch, .{
        .cpu = cpu,
        .features = set,
    });
}

// ABI warning
export fn stage2_cpu_features_get_cache_hash(
    cpu_features: *const Stage2CpuFeatures,
    ptr: *[*:0]const u8,
    len: *usize,
) void {
    ptr.* = cpu_features.cache_hash.ptr;
    len.* = cpu_features.cache_hash.len;
}

// ABI warning
export fn stage2_cpu_features_get_builtin_str(
    cpu_features: *const Stage2CpuFeatures,
    ptr: *[*:0]const u8,
    len: *usize,
) void {
    ptr.* = cpu_features.builtin_str.ptr;
    len.* = cpu_features.builtin_str.len;
}

// ABI warning
export fn stage2_cpu_features_get_llvm_cpu(cpu_features: *const Stage2CpuFeatures) ?[*:0]const u8 {
    return if (cpu_features.cpu_features.cpu.llvm_name) |s| s.ptr else null;
}

// ABI warning
export fn stage2_cpu_features_get_llvm_features(cpu_features: *const Stage2CpuFeatures) ?[*:0]const u8 {
    return cpu_features.llvm_features_str;
}
