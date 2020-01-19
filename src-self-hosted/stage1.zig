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

// ABI warning
export fn stage2_list_features_for_arch(arch_name_ptr: [*]const u8, arch_name_len: usize, show_dependencies: bool) void {
    printFeaturesForArch(arch_name_ptr[0..arch_name_len], show_dependencies) catch |err| {
        std.debug.warn("Failed to list features: {}\n", .{@errorName(err)});
    };
}

fn printFeaturesForArch(arch_name: []const u8, show_dependencies: bool) !void {
    const stdout_stream = &std.io.getStdOut().outStream().stream;

    const arch = Target.parseArchTag(arch_name) catch {
        std.debug.warn("Failed to parse arch '{}'\nInvoke 'zig targets' for a list of valid architectures\n", .{arch_name});
        return;
    };

    try stdout_stream.print("Available features for {}:\n", .{@tagName(arch)});

    const features = std.target.getFeaturesForArch(arch);

    var longest_len: usize = 0;
    for (features) |feature| {
        if (feature.name.len > longest_len) {
            longest_len = feature.name.len;
        }
    }

    for (features) |feature| {
        try stdout_stream.print("  {}", .{feature.name});

        var i: usize = 0;
        while (i < longest_len - feature.name.len) : (i += 1) {
            try stdout_stream.write(" ");
        }

        try stdout_stream.print(" - {}\n", .{feature.description});

        if (show_dependencies and feature.dependencies.len > 0) {
            for (feature.dependencies) |dependency| {
                try stdout_stream.print("    {}\n", .{dependency.name});
            }
        }
    }
}

// ABI warning
export fn stage2_list_cpus_for_arch(arch_name_ptr: [*]const u8, arch_name_len: usize, show_dependencies: bool) void {
    printCpusForArch(arch_name_ptr[0..arch_name_len], show_dependencies) catch |err| {
        std.debug.warn("Failed to list features: {}\n", .{@errorName(err)});
    };
}

fn printCpusForArch(arch_name: []const u8, show_dependencies: bool) !void {
    const stdout_stream = &std.io.getStdOut().outStream().stream;

    const arch = Target.parseArchTag(arch_name) catch {
        std.debug.warn("Failed to parse arch '{}'\nInvoke 'zig targets' for a list of valid architectures\n", .{arch_name});
        return;
    };

    const cpus = std.target.getCpusForArch(arch);

    try stdout_stream.print("Available cpus for {}:\n", .{@tagName(arch)});

    var longest_len: usize = 0;
    for (cpus) |cpu| {
        if (cpu.name.len > longest_len) {
            longest_len = cpu.name.len;
        }
    }

    for (cpus) |cpu| {
        try stdout_stream.print("  {}", .{cpu.name});

        var i: usize = 0;
        while (i < longest_len - cpu.name.len) : (i += 1) {
            try stdout_stream.write(" ");
        }

        try stdout_stream.write("\n");

        if (show_dependencies and cpu.dependencies.len > 0) {
            for (cpu.dependencies) |dependency| {
                try stdout_stream.print("    {}\n", .{dependency.name});
            }
        }
    }
}

const Stage2CpuFeatures = struct {
    allocator: *mem.Allocator,
    cpu_features: Target.CpuFeatures,

    llvm_cpu_name: ?[:0]const u8,
    llvm_features_str: ?[:0]const u8,

    builtin_str: [:0]const u8,
    cache_hash: [:0]const u8,

    const Self = @This();

    fn initBaseline(allocator: *mem.Allocator) !Self {
        const builtin_str = try std.fmt.allocPrint0(allocator, "CpuFeatures.baseline;\n");
        errdefer allocator.free(builtin_str);

        const cache_hash = try std.fmt.allocPrint0(allocator, "\n\n");
        errdefer allocator.free(cache_hash);

        return Self{
            .allocator = allocator,
            .cpu_features = .{ .cpu = cpu },
            .llvm_cpu_name = null,
            .llvm_features_str = null,
            .builtin_str = builtin_str,
            .cache_hash = cache_hash,
        };
    }

    fn initCpu(allocator: *mem.Allocator, arch: Target.Arch, cpu: *const Target.Cpu) !Self {
        const builtin_str = try std.fmt.allocPrint0(
            allocator,
            "CpuFeatures{{ .cpu = &Arch.{}.cpu.{} }};\n",
            arch.genericName(),
            cpu.name,
        );
        errdefer allocator.free(builtin_str);

        const cache_hash = try std.fmt.allocPrint0(allocator, "{}\n{x}", cpu.name, cpu.features);
        errdefer allocator.free(cache_hash);

        return Self{
            .allocator = allocator,
            .cpu_features = .{ .cpu = cpu },
            .llvm_cpu_name = cpu.llvm_name,
            .llvm_features_str = null,
            .builtin_str = builtin_str,
            .cache_hash = cache_hash,
        };
    }

    fn initFeatures(
        allocator: *mem.Allocator,
        arch: Target.Arch,
        features: Target.Cpu.Feature.Set,
    ) !Self {
        const cache_hash = try std.fmt.allocPrint0(allocator, "\n{x}", features);
        errdefer allocator.free(cache_hash);

        const generic_arch_name = arch.genericName();
        var builtin_str_buffer = try std.Buffer.allocPrint(
            allocator,
            "CpuFeatures{{ .features = Arch.{}.featureSet(&[_]Arch.{}.Feature{{\n",
            generic_arch_name,
            generic_arch_name,
        );
        defer builtin_str_buffer.deinit();

        var llvm_features_buffer = try std.Buffer.initSize(allocator, 0);
        defer llvm_features_buffer.deinit();

        // First, disable all features.
        // This way, we only get the ones the user requests.
        for (arch.allFeatures()) |feature| {
            if (feature.llvm_name) |llvm_name| {
                try llvm_features_buffer.append("-");
                try llvm_features_buffer.append(llvm_name);
                try llvm_features_buffer.append(",");
            }
        }

        for (features) |feature| {
            if (feature.llvm_name) |llvm_name| {
                try llvm_features_buffer.append("+");
                try llvm_features_buffer.append(llvm_name);
                try llvm_features_buffer.append(",");
            }

            try builtin_str_buffer.append("    .");
            try builtin_str_buffer.append(feature.name);
            try builtin_str_buffer.append(",\n");
        }

        if (mem.endsWith(u8, llvm_features_buffer.toSliceConst(), ",")) {
            llvm_features_buffer.shrink(llvm_features_buffer.len() - 1);
        }

        try builtin_str_buffer.append("})};\n");

        return Self{
            .allocator = allocator,
            .cpu_features = .{ .features = features },
            .llvm_cpu_name = null,
            .llvm_features_str = llvm_features_buffer.toOwnedSlice(),
            .builtin_str = builtin_str_buffer.toOwnedSlice(),
            .cache_hash = cache_hash,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.cache_hash);
        self.allocator.free(self.builtin_str);
        if (self.llvm_features_str) |llvm_features_str| self.allocator.free(llvm_features_str);
        self.* = undefined;
    }
};

// ABI warning
export fn stage2_cpu_features_parse_cpu(arch_name: [*:0]const u8, cpu_name: [*:0]const u8) *Stage2CpuFeatures {
    return parseCpu(arch_name, cpu_name) catch |err| switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    };
}

fn parseCpu(arch_name: [*:0]const u8, cpu_name: [*:0]const u8) !*Stage2CpuFeatures {
    const arch = try Target.parseArchSub(mem.toSliceConst(u8, arch_name));
    const cpu = try arch.parseCpu(mem.toSliceConst(u8, cpu_name));

    const ptr = try allocator.create(Stage2CpuFeatures);
    errdefer std.heap.c_allocator.destroy(ptr);

    ptr.* = try Stage2CpuFeatures.initCpu(std.heap.c_allocator, arch, cpu);
    errdefer ptr.deinit();

    return ptr;
}

// ABI warning
export fn stage2_cpu_features_parse_features(
    arch_name: [*:0]const u8,
    features_text: [*:0]const u8,
) *Stage2CpuFeatures {
    return parseFeatures(arch_name, features_text) catch |err| switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    };
}

fn parseFeatures(arch_name: [*:0]const u8, features_text: [*:0]const u8) !*Stage2CpuFeatures {
    const arch = try Target.parseArchSub(mem.toSliceConst(u8, arch_name));
    const set = try arch.parseCpuFeatureSet(mem.toSliceConst(u8, features_text));

    const ptr = try std.heap.c_allocator.create(Stage2CpuFeatures);
    errdefer std.heap.c_allocator.destroy(ptr);

    ptr.* = try Stage2CpuFeatures.initFeatures(std.heap.c_allocator, arch, set);
    errdefer ptr.deinit();

    return ptr;
}

// ABI warning
export fn stage2_cpu_features_baseline() *Stage2CpuFeatures {
    const ptr = try std.heap.c_allocator.create(Stage2CpuFeatures);
    errdefer std.heap.c_allocator.destroy(ptr);

    ptr.* = try Stage2CpuFeatures.initBaseline(std.heap.c_allocator);
    errdefer ptr.deinit();

    return ptr;
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
    return cpu_features.llvm_cpu_name;
}

// ABI warning
export fn stage2_cpu_features_get_llvm_features(cpu_features: *const Stage2CpuFeatures) ?[*:0]const u8 {
    return cpu_features.llvm_features_str;
}
