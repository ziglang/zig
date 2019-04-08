const std = @import("std");
const builtin = @import("builtin");

const os = std.os;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const ast = std.zig.ast;

const arg = @import("fmt/arg.zig");
const self_hosted_main = @import("fmt/main.zig");
const Args = arg.Args;
const Flag = arg.Flag;
const errmsg = @import("fmt/errmsg.zig");

var stderr_file: os.File = undefined;
var stderr: *io.OutStream(os.File.WriteError) = undefined;
var stdout: *io.OutStream(os.File.WriteError) = undefined;

// This brings `zig fmt` to stage 1.
pub fn main() !void {
    // Here we use an ArenaAllocator backed by a DirectAllocator because `zig fmt` is a short-lived,
    // one shot program. We don't need to waste time freeing memory and finding places to squish
    // bytes into. So we free everything all at once at the very end.
    var direct_allocator = std.heap.DirectAllocator.init();
    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    const allocator = &arena.allocator;

    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    stdout = &stdout_out_stream.stream;

    stderr_file = try std.io.getStdErr();
    var stderr_out_stream = stderr_file.outStream();
    stderr = &stderr_out_stream.stream;
    const args = try std.os.argsAlloc(allocator);

    var flags = try Args.parse(allocator, self_hosted_main.args_fmt_spec, args[1..]);
    defer flags.deinit();

    if (flags.present("help")) {
        try stdout.write(self_hosted_main.usage_fmt);
        os.exit(0);
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
            os.exit(1);
        }

        var stdin_file = try io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.stream.readAllAlloc(allocator, self_hosted_main.max_src_size);
        defer allocator.free(source_code);

        var err_loc: usize = undefined;
        var tree = std.zig.parse(allocator, source_code, &err_loc) catch |err| {
            try stderr.print("error parsing stdin at byte {}: {}\n", err_loc, err);
            os.exit(1);
        };
        defer tree.deinit();

        var error_it = tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            try printErrMsgToFile(allocator, parse_error, &tree, "<stdin>", stderr_file, color);
        }
        if (tree.errors.len != 0) {
            os.exit(1);
        }
        if (flags.present("check")) {
            const anything_changed = try std.zig.render(allocator, io.null_out_stream, &tree);
            const code = if (anything_changed) u8(1) else u8(0);
            os.exit(code);
        }

        _ = try std.zig.render(allocator, stdout, &tree);
        return;
    }

    if (flags.positionals.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        os.exit(1);
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
        os.exit(1);
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
} || os.File.OpenError;

fn fmtPath(fmt: *Fmt, file_path_ref: []const u8, check_mode: bool) FmtError!void {
    const file_path = try std.mem.dupe(fmt.allocator, u8, file_path_ref);
    defer fmt.allocator.free(file_path);

    if (try fmt.seen.put(file_path, {})) |_| return;

    const source_code = io.readFileAlloc(fmt.allocator, file_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => {
            // TODO make event based (and dir.next())
            var dir = try std.os.Dir.open(fmt.allocator, file_path);
            defer dir.close();

            while (try dir.next()) |entry| {
                if (entry.kind == std.os.Dir.Entry.Kind.Directory or mem.endsWith(u8, entry.name, ".zig")) {
                    const full_path = try os.path.join(fmt.allocator, [][]const u8{ file_path, entry.name });
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

    var err_loc: usize = undefined;
    var tree = std.zig.parse(fmt.allocator, source_code, &err_loc) catch |err| {
        try stderr.print("error parsing file '{}' at byte {}: {}\n", file_path, err_loc, err);
        fmt.any_error = true;
        return;
    };
    defer tree.deinit();

    var error_it = tree.errors.iterator(0);
    while (error_it.next()) |parse_error| {
        try printErrMsgToFile(fmt.allocator, parse_error, &tree, file_path, stderr_file, fmt.color);
    }
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (check_mode) {
        const anything_changed = try std.zig.render(fmt.allocator, io.null_out_stream, &tree);
        if (anything_changed) {
            try stderr.print("{}\n", file_path);
            fmt.any_error = true;
        }
    } else {
        // TODO make this evented
        const baf = try io.BufferedAtomicFile.create(fmt.allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(fmt.allocator, baf.stream(), &tree);
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

fn printErrMsgToFile(allocator: *mem.Allocator, parse_error: *const ast.Error, tree: *ast.Tree,
    path: []const u8, file: os.File, color: errmsg.Color,) !void
{
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
