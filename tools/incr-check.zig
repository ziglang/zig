const std = @import("std");
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;

const usage = "usage: incr-check <zig binary path> <input file> [-fno-emit-bin] [--zig-lib-dir lib]";

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var opt_zig_exe: ?[]const u8 = null;
    var opt_input_file_name: ?[]const u8 = null;
    var opt_lib_dir: ?[]const u8 = null;
    var no_bin = false;

    var arg_it = try std.process.argsWithAllocator(arena);
    _ = arg_it.skip();
    while (arg_it.next()) |arg| {
        if (arg.len > 0 and arg[0] == '-') {
            if (std.mem.eql(u8, arg, "-fno-emit-bin")) {
                no_bin = true;
            } else if (std.mem.eql(u8, arg, "--zig-lib-dir")) {
                opt_lib_dir = arg_it.next() orelse fatal("expected arg after '--zig-lib-dir'\n{s}", .{usage});
            } else {
                fatal("unknown option '{s}'\n{s}", .{ arg, usage });
            }
            continue;
        }
        if (opt_zig_exe == null) {
            opt_zig_exe = arg;
        } else if (opt_input_file_name == null) {
            opt_input_file_name = arg;
        } else {
            fatal("unknown argument '{s}'\n{s}", .{ arg, usage });
        }
    }
    const zig_exe = opt_zig_exe orelse fatal("missing path to zig\n{s}", .{usage});
    const input_file_name = opt_input_file_name orelse fatal("missing input file\n{s}", .{usage});

    const input_file_bytes = try std.fs.cwd().readFileAlloc(arena, input_file_name, std.math.maxInt(u32));
    const case = try Case.parse(arena, input_file_bytes);

    const prog_node = std.Progress.start(.{});
    defer prog_node.end();

    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_path = "tmp_" ++ std.fmt.hex(rand_int);
    const tmp_dir = try std.fs.cwd().makeOpenPath(tmp_dir_path, .{});

    const child_prog_node = prog_node.start("zig build-exe", 0);
    defer child_prog_node.end();

    var child_args: std.ArrayListUnmanaged([]const u8) = .{};
    try child_args.appendSlice(arena, &.{
        // Convert incr-check-relative path to subprocess-relative path.
        try std.fs.path.relative(arena, tmp_dir_path, zig_exe),
        "build-exe",
        case.root_source_file,
        "-fincremental",
        "-target",
        case.target_query,
        "--cache-dir",
        ".local-cache",
        "--global-cache-dir",
        ".global_cache",
        "--listen=-",
    });
    if (opt_lib_dir) |lib_dir| {
        try child_args.appendSlice(arena, &.{ "--zig-lib-dir", lib_dir });
    }
    if (no_bin) {
        try child_args.append(arena, "-fno-emit-bin");
    } else {
        try child_args.appendSlice(arena, &.{ "-fno-llvm", "-fno-lld" });
    }

    var child = std.process.Child.init(child_args.items, arena);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.progress_node = child_prog_node;
    child.cwd_dir = tmp_dir;
    child.cwd = tmp_dir_path;

    var eval: Eval = .{
        .arena = arena,
        .case = case,
        .tmp_dir = tmp_dir,
        .tmp_dir_path = tmp_dir_path,
        .child = &child,
    };

    try child.spawn();

    var poller = std.io.poll(arena, Eval.StreamEnum, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    for (case.updates) |update| {
        var update_node = prog_node.start(update.name, 0);
        defer update_node.end();
        eval.write(update);
        try eval.requestUpdate();
        try eval.check(&poller, update);
    }

    try eval.end(&poller);

    waitChild(&child);
}

const Eval = struct {
    arena: Allocator,
    case: Case,
    tmp_dir: std.fs.Dir,
    tmp_dir_path: []const u8,
    child: *std.process.Child,

    const StreamEnum = enum { stdout, stderr };
    const Poller = std.io.Poller(StreamEnum);

    /// Currently this function assumes the previous updates have already been written.
    fn write(eval: *Eval, update: Case.Update) void {
        for (update.changes) |full_contents| {
            eval.tmp_dir.writeFile(.{
                .sub_path = full_contents.name,
                .data = full_contents.bytes,
            }) catch |err| {
                fatal("failed to update '{s}': {s}", .{ full_contents.name, @errorName(err) });
            };
        }
        for (update.deletes) |doomed_name| {
            eval.tmp_dir.deleteFile(doomed_name) catch |err| {
                fatal("failed to delete '{s}': {s}", .{ doomed_name, @errorName(err) });
            };
        }
    }

    fn check(eval: *Eval, poller: *Poller, update: Case.Update) !void {
        const arena = eval.arena;
        const Header = std.zig.Server.Message.Header;
        const stdout = poller.fifo(.stdout);
        const stderr = poller.fifo(.stderr);

        poll: while (true) {
            while (stdout.readableLength() < @sizeOf(Header)) {
                if (!(try poller.poll())) break :poll;
            }
            const header = stdout.reader().readStruct(Header) catch unreachable;
            while (stdout.readableLength() < header.bytes_len) {
                if (!(try poller.poll())) break :poll;
            }
            const body = stdout.readableSliceOfLen(header.bytes_len);

            switch (header.tag) {
                .error_bundle => {
                    const EbHdr = std.zig.Server.Message.ErrorBundle;
                    const eb_hdr = @as(*align(1) const EbHdr, @ptrCast(body));
                    const extra_bytes =
                        body[@sizeOf(EbHdr)..][0 .. @sizeOf(u32) * eb_hdr.extra_len];
                    const string_bytes =
                        body[@sizeOf(EbHdr) + extra_bytes.len ..][0..eb_hdr.string_bytes_len];
                    // TODO: use @ptrCast when the compiler supports it
                    const unaligned_extra = std.mem.bytesAsSlice(u32, extra_bytes);
                    const extra_array = try arena.alloc(u32, unaligned_extra.len);
                    @memcpy(extra_array, unaligned_extra);
                    const result_error_bundle: std.zig.ErrorBundle = .{
                        .string_bytes = try arena.dupe(u8, string_bytes),
                        .extra = extra_array,
                    };
                    if (stderr.readableLength() > 0) {
                        const stderr_data = try stderr.toOwnedSlice();
                        fatal("error_bundle included unexpected stderr:\n{s}", .{stderr_data});
                    }
                    if (result_error_bundle.errorMessageCount() == 0) {
                        // Empty bundle indicates successful update in a `-fno-emit-bin` build.
                        // We can't do a full success check since we don't have a binary, but let's
                        // at least check that no errors were expected.
                        switch (update.outcome) {
                            .unknown, .stdout, .exit_code => {},
                            .compile_errors => fatal("expected compile errors but compilation incorrectly succeeded", .{}),
                        }
                    } else {
                        try eval.checkErrorOutcome(update, result_error_bundle);
                    }
                    // This message indicates the end of the update.
                    stdout.discard(body.len);
                    return;
                },
                .emit_bin_path => {
                    const EbpHdr = std.zig.Server.Message.EmitBinPath;
                    const ebp_hdr = @as(*align(1) const EbpHdr, @ptrCast(body));
                    _ = ebp_hdr;
                    const result_binary = try arena.dupe(u8, body[@sizeOf(EbpHdr)..]);
                    if (stderr.readableLength() > 0) {
                        const stderr_data = try stderr.toOwnedSlice();
                        fatal("emit_bin_path included unexpected stderr:\n{s}", .{stderr_data});
                    }
                    try eval.checkSuccessOutcome(update, result_binary);
                    // This message indicates the end of the update.
                    stdout.discard(body.len);
                    return;
                },
                else => {
                    // Ignore other messages.
                    stdout.discard(body.len);
                },
            }
        }

        if (stderr.readableLength() > 0) {
            const stderr_data = try stderr.toOwnedSlice();
            fatal("update '{s}' failed:\n{s}", .{ update.name, stderr_data });
        }

        waitChild(eval.child);
        fatal("update '{s}': compiler failed to send error_bundle or emit_bin_path", .{update.name});
    }

    fn checkErrorOutcome(eval: *Eval, update: Case.Update, error_bundle: std.zig.ErrorBundle) !void {
        _ = eval;
        switch (update.outcome) {
            .unknown => return,
            .compile_errors => |expected_errors| {
                for (expected_errors) |expected_error| {
                    _ = expected_error;
                    @panic("TODO check if the expected error matches the compile errors");
                }
            },
            .stdout, .exit_code => {
                const color: std.zig.Color = .auto;
                error_bundle.renderToStdErr(color.renderOptions());
                fatal("update '{s}': unexpected compile errors", .{update.name});
            },
        }
    }

    fn checkSuccessOutcome(eval: *Eval, update: Case.Update, binary_path: []const u8) !void {
        switch (update.outcome) {
            .unknown => return,
            .compile_errors => fatal("expected compile errors but compilation incorrectly succeeded", .{}),
            .stdout, .exit_code => {},
        }
        const result = std.process.Child.run(.{
            .allocator = eval.arena,
            .argv = &.{binary_path},
            .cwd_dir = eval.tmp_dir,
            .cwd = eval.tmp_dir_path,
        }) catch |err| {
            fatal("update '{s}': failed to run the generated executable '{s}': {s}", .{
                update.name, binary_path, @errorName(err),
            });
        };
        if (result.stderr.len != 0) {
            std.log.err("update '{s}': generated executable '{s}' had unexpected stderr:\n{s}", .{
                update.name, binary_path, result.stderr,
            });
        }
        switch (result.term) {
            .Exited => |code| switch (update.outcome) {
                .unknown, .compile_errors => unreachable,
                .stdout => |expected_stdout| {
                    if (code != 0) {
                        fatal("update '{s}': generated executable '{s}' failed with code {d}", .{
                            update.name, binary_path, code,
                        });
                    }
                    try std.testing.expectEqualStrings(expected_stdout, result.stdout);
                },
                .exit_code => |expected_code| try std.testing.expectEqual(expected_code, result.term.Exited),
            },
            .Signal, .Stopped, .Unknown => {
                fatal("update '{s}': generated executable '{s}' terminated unexpectedly", .{
                    update.name, binary_path,
                });
            },
        }
        if (result.stderr.len != 0) std.process.exit(1);
    }

    fn requestUpdate(eval: *Eval) !void {
        const header: std.zig.Client.Message.Header = .{
            .tag = .update,
            .bytes_len = 0,
        };
        try eval.child.stdin.?.writeAll(std.mem.asBytes(&header));
    }

    fn end(eval: *Eval, poller: *Poller) !void {
        requestExit(eval.child);

        const Header = std.zig.Server.Message.Header;
        const stdout = poller.fifo(.stdout);
        const stderr = poller.fifo(.stderr);

        poll: while (true) {
            while (stdout.readableLength() < @sizeOf(Header)) {
                if (!(try poller.poll())) break :poll;
            }
            const header = stdout.reader().readStruct(Header) catch unreachable;
            while (stdout.readableLength() < header.bytes_len) {
                if (!(try poller.poll())) break :poll;
            }
            const body = stdout.readableSliceOfLen(header.bytes_len);
            stdout.discard(body.len);
        }

        if (stderr.readableLength() > 0) {
            const stderr_data = try stderr.toOwnedSlice();
            fatal("unexpected stderr:\n{s}", .{stderr_data});
        }
    }
};

const Case = struct {
    updates: []Update,
    root_source_file: []const u8,
    target_query: []const u8,

    const Update = struct {
        name: []const u8,
        outcome: Outcome,
        changes: []const FullContents = &.{},
        deletes: []const []const u8 = &.{},
    };

    const FullContents = struct {
        name: []const u8,
        bytes: []const u8,
    };

    const Outcome = union(enum) {
        unknown,
        compile_errors: []const ExpectedError,
        stdout: []const u8,
        exit_code: u8,
    };

    const ExpectedError = struct {
        file_name: ?[]const u8 = null,
        line: ?u32 = null,
        column: ?u32 = null,
        msg_exact: ?[]const u8 = null,
        msg_substring: ?[]const u8 = null,
    };

    fn parse(arena: Allocator, bytes: []const u8) !Case {
        var updates: std.ArrayListUnmanaged(Update) = .{};
        var changes: std.ArrayListUnmanaged(FullContents) = .{};
        var target_query: ?[]const u8 = null;
        var it = std.mem.splitScalar(u8, bytes, '\n');
        var line_n: usize = 1;
        var root_source_file: ?[]const u8 = null;
        while (it.next()) |line| : (line_n += 1) {
            if (std.mem.startsWith(u8, line, "#")) {
                var line_it = std.mem.splitScalar(u8, line, '=');
                const key = line_it.first()[1..];
                const val = line_it.rest();
                if (val.len == 0) {
                    fatal("line {d}: missing value", .{line_n});
                } else if (std.mem.eql(u8, key, "target")) {
                    if (target_query != null) fatal("line {d}: duplicate target", .{line_n});
                    target_query = val;
                } else if (std.mem.eql(u8, key, "update")) {
                    if (updates.items.len > 0) {
                        const last_update = &updates.items[updates.items.len - 1];
                        last_update.changes = try changes.toOwnedSlice(arena);
                    }
                    try updates.append(arena, .{
                        .name = val,
                        .outcome = .unknown,
                    });
                } else if (std.mem.eql(u8, key, "file")) {
                    if (updates.items.len == 0) fatal("line {d}: expect directive before update", .{line_n});

                    if (root_source_file == null)
                        root_source_file = val;

                    const start_index = it.index.?;
                    const src = while (true) : (line_n += 1) {
                        const old = it;
                        const next_line = it.next() orelse fatal("line {d}: unexpected EOF", .{line_n});
                        if (std.mem.startsWith(u8, next_line, "#")) {
                            const end_index = old.index.?;
                            const src = bytes[start_index..end_index];
                            it = old;
                            break src;
                        }
                    };

                    try changes.append(arena, .{
                        .name = val,
                        .bytes = src,
                    });
                } else if (std.mem.eql(u8, key, "expect_stdout")) {
                    if (updates.items.len == 0) fatal("line {d}: expect directive before update", .{line_n});
                    const last_update = &updates.items[updates.items.len - 1];
                    if (last_update.outcome != .unknown) fatal("line {d}: conflicting expect directive", .{line_n});
                    last_update.outcome = .{
                        .stdout = std.zig.string_literal.parseAlloc(arena, val) catch |err| {
                            fatal("line {d}: bad string literal: {s}", .{ line_n, @errorName(err) });
                        },
                    };
                } else if (std.mem.eql(u8, key, "expect_error")) {
                    if (updates.items.len == 0) fatal("line {d}: expect directive before update", .{line_n});
                    const last_update = &updates.items[updates.items.len - 1];
                    if (last_update.outcome != .unknown) fatal("line {d}: conflicting expect directive", .{line_n});
                    last_update.outcome = .{ .compile_errors = &.{} };
                } else {
                    fatal("line {d}: unrecognized key '{s}'", .{ line_n, key });
                }
            }
        }

        if (changes.items.len > 0) {
            const last_update = &updates.items[updates.items.len - 1];
            last_update.changes = try changes.toOwnedSlice(arena);
        }

        return .{
            .updates = updates.items,
            .root_source_file = root_source_file orelse fatal("missing root source file", .{}),
            .target_query = target_query orelse fatal("missing target", .{}),
        };
    }
};

fn requestExit(child: *std.process.Child) void {
    if (child.stdin == null) return;

    const header: std.zig.Client.Message.Header = .{
        .tag = .exit,
        .bytes_len = 0,
    };
    child.stdin.?.writeAll(std.mem.asBytes(&header)) catch |err| switch (err) {
        error.BrokenPipe => {},
        else => fatal("failed to send exit: {s}", .{@errorName(err)}),
    };

    // Send EOF to stdin.
    child.stdin.?.close();
    child.stdin = null;
}

fn waitChild(child: *std.process.Child) void {
    requestExit(child);
    const term = child.wait() catch |err| fatal("child process failed: {s}", .{@errorName(err)});
    switch (term) {
        .Exited => |code| if (code != 0) fatal("compiler failed with code {d}", .{code}),
        .Signal, .Stopped, .Unknown => fatal("compiler terminated unexpectedly", .{}),
    }
}
