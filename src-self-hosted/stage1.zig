// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.

const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const arg = @import("arg.zig");
const self_hosted_main = @import("main.zig");
const Args = arg.Args;
const Flag = arg.Flag;
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
    ptr.* = &info_zen;
    len.* = info_zen.len;
}

// ABI warning
export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}

// ABI warning
const TranslateMode = extern enum {
    import,
    translate,
};

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
    mode: TranslateMode,
    resources_path: [*]const u8,
) Error {
    var errors: []translate_c.ClangErrMsg = undefined;
    out_ast.* = translate_c.translate(std.heap.c_allocator, args_begin, args_end, switch (mode) {
        .import => translate_c.Mode.import,
        .translate => translate_c.Mode.translate,
    }, &errors, resources_path) catch |err| switch (err) {
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

// TODO: just use the actual self-hosted zig fmt. Until the coroutine rewrite, we use a blocking implementation.
export fn stage2_fmt(argc: c_int, argv: [*]const [*]const u8) c_int {
    if (std.debug.runtime_safety) {
        fmtMain(argc, argv) catch unreachable;
    } else {
        fmtMain(argc, argv) catch |e| {
            std.debug.warn("{}\n", @errorName(e));
            return -1;
        };
    }
    return 0;
}

fn fmtMain(argc: c_int, argv: [*]const [*]const u8) !void {
    const allocator = std.heap.c_allocator;
    var args_list = std.ArrayList([]const u8).init(allocator);
    const argc_usize = @intCast(usize, argc);
    var arg_i: usize = 0;
    while (arg_i < argc_usize) : (arg_i += 1) {
        try args_list.append(std.mem.toSliceConst(u8, argv[arg_i]));
    }

    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    stdout = &stdout_out_stream.stream;

    stderr_file = try std.io.getStdErr();
    var stderr_out_stream = stderr_file.outStream();
    stderr = &stderr_out_stream.stream;

    const args = args_list.toSliceConst();
    var flags = try Args.parse(allocator, self_hosted_main.args_fmt_spec, args[2..]);
    defer flags.deinit();

    if (flags.present("help")) {
        try stdout.write(self_hosted_main.usage_fmt);
        process.exit(0);
    }

    const color = blk: {
        if (flags.single("color")) |color_flag| {
            if (mem.eql(u8, color_flag, "auto")) {
                break :blk errmsg.Color.Auto;
            } else if (mem.eql(u8, color_flag, "on")) {
                break :blk errmsg.Color.On;
            } else if (mem.eql(u8, color_flag, "off")) {
                break :blk errmsg.Color.Off;
            } else unreachable;
        } else {
            break :blk errmsg.Color.Auto;
        }
    };

    if (flags.present("stdin")) {
        if (flags.positionals.len != 0) {
            try stderr.write("cannot use --stdin with positional arguments\n");
            process.exit(1);
        }

        var stdin_file = try io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.stream.readAllAlloc(allocator, self_hosted_main.max_src_size);
        defer allocator.free(source_code);

        const tree = std.zig.parse(allocator, source_code) catch |err| {
            try stderr.print("error parsing stdin: {}\n", err);
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
        if (flags.present("check")) {
            const anything_changed = try std.zig.render(allocator, io.null_out_stream, tree);
            const code = if (anything_changed) u8(1) else u8(0);
            process.exit(code);
        }

        _ = try std.zig.render(allocator, stdout, tree);
        return;
    }

    if (flags.positionals.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        process.exit(1);
    }

    var fmt = Fmt{
        .seen = Fmt.SeenMap.init(allocator),
        .any_error = false,
        .color = color,
        .allocator = allocator,
    };

    const check_mode = flags.present("check");

    for (flags.positionals.toSliceConst()) |file_path| {
        try fmtPath(&fmt, file_path, check_mode);
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

fn fmtPath(fmt: *Fmt, file_path_ref: []const u8, check_mode: bool) FmtError!void {
    const file_path = try std.mem.dupe(fmt.allocator, u8, file_path_ref);
    defer fmt.allocator.free(file_path);

    if (try fmt.seen.put(file_path, {})) |_| return;

    const source_code = io.readFileAlloc(fmt.allocator, file_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => {
            // TODO make event based (and dir.next())
            var dir = try fs.Dir.open(fmt.allocator, file_path);
            defer dir.close();

            while (try dir.next()) |entry| {
                if (entry.kind == fs.Dir.Entry.Kind.Directory or mem.endsWith(u8, entry.name, ".zig")) {
                    const full_path = try fs.path.join(fmt.allocator, [_][]const u8{ file_path, entry.name });
                    try fmtPath(fmt, full_path, check_mode);
                }
            }
            return;
        },
        else => {
            // TODO lock stderr printing
            try stderr.print("unable to open '{}': {}\n", file_path, err);
            fmt.any_error = true;
            return;
        },
    };
    defer fmt.allocator.free(source_code);

    const tree = std.zig.parse(fmt.allocator, source_code) catch |err| {
        try stderr.print("error parsing file '{}': {}\n", file_path, err);
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
            try stderr.print("{}\n", file_path);
            fmt.any_error = true;
        }
    } else {
        const baf = try io.BufferedAtomicFile.create(fmt.allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(fmt.allocator, baf.stream(), tree);
        if (anything_changed) {
            try stderr.print("{}\n", file_path);
            try baf.finish();
        }
    }
}

const Fmt = struct {
    seen: SeenMap,
    any_error: bool,
    color: errmsg.Color,
    allocator: *mem.Allocator,

    const SeenMap = std.HashMap([]const u8, void, mem.hash_slice_u8, mem.eql_slice_u8);
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
        errmsg.Color.Auto => file.isTty(),
        errmsg.Color.On => true,
        errmsg.Color.Off => false,
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
    if (!color_on) {
        try stream.print(
            "{}:{}:{}: error: {}\n",
            path,
            start_loc.line + 1,
            start_loc.column + 1,
            text,
        );
        return;
    }

    try stream.print(
        "{}:{}:{}: error: {}\n{}\n",
        path,
        start_loc.line + 1,
        start_loc.column + 1,
        text,
        tree.source[start_loc.line_start..start_loc.line_end],
    );
    try stream.writeByteNTimes(' ', start_loc.column);
    try stream.writeByteNTimes('~', last_token.end - first_token.start);
    try stream.write("\n");
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
            .target => stage2_DepNextResult.TypeId.target,
            .prereq => stage2_DepNextResult.TypeId.prereq,
        },
        .textz = textz.toSlice().ptr,
    };
}

export const stage2_DepTokenizer = extern struct {
    handle: *DepTokenizer,
};

export const stage2_DepNextResult = extern struct {
    type_id: TypeId,

    // when type_id == error --> error text
    // when type_id == null --> undefined
    // when type_id == target --> target pathname
    // when type_id == prereq --> prereq pathname
    textz: [*]const u8,

    export const TypeId = extern enum {
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
