const std = @import("std");
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;

const usage = "usage: incr-check <zig binary path> <input file> [--zig-lib-dir lib] [--debug-zcu] [--emit none|bin|c] [--zig-cc-binary /path/to/zig]";

const EmitMode = enum {
    none,
    bin,
    c,
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var opt_zig_exe: ?[]const u8 = null;
    var opt_input_file_name: ?[]const u8 = null;
    var opt_lib_dir: ?[]const u8 = null;
    var opt_cc_zig: ?[]const u8 = null;
    var emit: EmitMode = .bin;
    var debug_zcu = false;

    var arg_it = try std.process.argsWithAllocator(arena);
    _ = arg_it.skip();
    while (arg_it.next()) |arg| {
        if (arg.len > 0 and arg[0] == '-') {
            if (std.mem.eql(u8, arg, "--emit")) {
                const emit_str = arg_it.next() orelse fatal("expected arg after '--emit'\n{s}", .{usage});
                emit = std.meta.stringToEnum(EmitMode, emit_str) orelse
                    fatal("invalid emit mode '{s}'\n{s}", .{ emit_str, usage });
            } else if (std.mem.eql(u8, arg, "--zig-lib-dir")) {
                opt_lib_dir = arg_it.next() orelse fatal("expected arg after '--zig-lib-dir'\n{s}", .{usage});
            } else if (std.mem.eql(u8, arg, "--debug-zcu")) {
                debug_zcu = true;
            } else if (std.mem.eql(u8, arg, "--zig-cc-binary")) {
                opt_cc_zig = arg_it.next() orelse fatal("expect arg after '--zig-cc-binary'\n{s}", .{usage});
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

    // Convert paths to be relative to the cwd of the subprocess.
    const resolved_zig_exe = try std.fs.path.relative(arena, tmp_dir_path, zig_exe);
    const opt_resolved_lib_dir = if (opt_lib_dir) |lib_dir|
        try std.fs.path.relative(arena, tmp_dir_path, lib_dir)
    else
        null;

    var child_args: std.ArrayListUnmanaged([]const u8) = .empty;
    try child_args.appendSlice(arena, &.{
        resolved_zig_exe,
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
    if (opt_resolved_lib_dir) |resolved_lib_dir| {
        try child_args.appendSlice(arena, &.{ "--zig-lib-dir", resolved_lib_dir });
    }
    switch (emit) {
        .bin => try child_args.appendSlice(arena, &.{ "-fno-llvm", "-fno-lld" }),
        .none => try child_args.append(arena, "-fno-emit-bin"),
        .c => try child_args.appendSlice(arena, &.{ "-ofmt=c", "-lc" }),
    }
    if (debug_zcu) {
        try child_args.appendSlice(arena, &.{ "--debug-log", "zcu" });
    }

    var child = std.process.Child.init(child_args.items, arena);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.progress_node = child_prog_node;
    child.cwd_dir = tmp_dir;
    child.cwd = tmp_dir_path;

    var cc_child_args: std.ArrayListUnmanaged([]const u8) = .empty;
    if (emit == .c) {
        const resolved_cc_zig_exe = if (opt_cc_zig) |cc_zig_exe|
            try std.fs.path.relative(arena, tmp_dir_path, cc_zig_exe)
        else
            resolved_zig_exe;

        try cc_child_args.appendSlice(arena, &.{
            resolved_cc_zig_exe,
            "cc",
            "-target",
            case.target_query,
            "-I",
            opt_resolved_lib_dir orelse fatal("'--zig-lib-dir' required when using '--emit c'", .{}),
            "-o",
        });
    }

    var eval: Eval = .{
        .arena = arena,
        .case = case,
        .tmp_dir = tmp_dir,
        .tmp_dir_path = tmp_dir_path,
        .child = &child,
        .allow_stderr = debug_zcu,
        .emit = emit,
        .cc_child_args = &cc_child_args,
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

        if (debug_zcu) {
            std.log.info("=== START UPDATE '{s}' ===", .{update.name});
        }

        eval.write(update);
        try eval.requestUpdate();
        try eval.check(&poller, update, update_node);
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
    allow_stderr: bool,
    emit: EmitMode,
    /// When `emit == .c`, this contains the first few arguments to `zig cc` to build the generated binary.
    /// The arguments `out.c in.c` must be appended before spawning the subprocess.
    cc_child_args: *std.ArrayListUnmanaged([]const u8),

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

    fn check(eval: *Eval, poller: *Poller, update: Case.Update, prog_node: std.Progress.Node) !void {
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
                        if (eval.allow_stderr) {
                            std.log.info("error_bundle included stderr:\n{s}", .{stderr_data});
                        } else {
                            fatal("error_bundle included unexpected stderr:\n{s}", .{stderr_data});
                        }
                    }
                    if (result_error_bundle.errorMessageCount() != 0) {
                        try eval.checkErrorOutcome(update, result_error_bundle);
                    }
                    // This message indicates the end of the update.
                    stdout.discard(body.len);
                    return;
                },
                .emit_digest => {
                    const EbpHdr = std.zig.Server.Message.EmitDigest;
                    const ebp_hdr = @as(*align(1) const EbpHdr, @ptrCast(body));
                    _ = ebp_hdr;
                    if (stderr.readableLength() > 0) {
                        const stderr_data = try stderr.toOwnedSlice();
                        if (eval.allow_stderr) {
                            std.log.info("emit_digest included stderr:\n{s}", .{stderr_data});
                        } else {
                            fatal("emit_digest included unexpected stderr:\n{s}", .{stderr_data});
                        }
                    }

                    if (eval.emit == .none) {
                        try eval.checkSuccessOutcome(update, null, prog_node);
                        // This message indicates the end of the update.
                        stdout.discard(body.len);
                        return;
                    }

                    const digest = body[@sizeOf(EbpHdr)..][0..Cache.bin_digest_len];
                    const result_dir = ".local-cache" ++ std.fs.path.sep_str ++ "o" ++ std.fs.path.sep_str ++ Cache.binToHex(digest.*);

                    const name = std.fs.path.stem(std.fs.path.basename(eval.case.root_source_file));
                    const bin_name = try std.zig.binNameAlloc(arena, .{
                        .root_name = name,
                        .target = try std.zig.system.resolveTargetQuery(try std.Build.parseTargetQuery(.{
                            .arch_os_abi = eval.case.target_query,
                            .object_format = switch (eval.emit) {
                                .none => unreachable,
                                .bin => null,
                                .c => "c",
                            },
                        })),
                        .output_mode = .Exe,
                    });
                    const bin_path = try std.fs.path.join(arena, &.{ result_dir, bin_name });

                    try eval.checkSuccessOutcome(update, bin_path, prog_node);
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
            if (eval.allow_stderr) {
                std.log.info("update '{s}' included stderr:\n{s}", .{ update.name, stderr_data });
            } else {
                fatal("update '{s}' failed:\n{s}", .{ update.name, stderr_data });
            }
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

    fn checkSuccessOutcome(eval: *Eval, update: Case.Update, opt_emitted_path: ?[]const u8, prog_node: std.Progress.Node) !void {
        switch (update.outcome) {
            .unknown => return,
            .compile_errors => fatal("expected compile errors but compilation incorrectly succeeded", .{}),
            .stdout, .exit_code => {},
        }
        const emitted_path = opt_emitted_path orelse {
            std.debug.assert(eval.emit == .none);
            return;
        };

        const binary_path = switch (eval.emit) {
            .none => unreachable,
            .bin => emitted_path,
            .c => bin: {
                const rand_int = std.crypto.random.int(u64);
                const out_bin_name = "./out_" ++ std.fmt.hex(rand_int);
                try eval.buildCOutput(update, emitted_path, out_bin_name, prog_node);
                break :bin out_bin_name;
            },
        };

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

    fn buildCOutput(eval: *Eval, update: Case.Update, c_path: []const u8, out_path: []const u8, prog_node: std.Progress.Node) !void {
        std.debug.assert(eval.cc_child_args.items.len > 0);

        const child_prog_node = prog_node.start("build cbe output", 0);
        defer child_prog_node.end();

        try eval.cc_child_args.appendSlice(eval.arena, &.{ out_path, c_path });
        defer eval.cc_child_args.items.len -= 2;

        const result = std.process.Child.run(.{
            .allocator = eval.arena,
            .argv = eval.cc_child_args.items,
            .cwd_dir = eval.tmp_dir,
            .cwd = eval.tmp_dir_path,
            .progress_node = child_prog_node,
        }) catch |err| {
            fatal("update '{s}': failed to spawn zig cc for '{s}': {s}", .{
                update.name, c_path, @errorName(err),
            });
        };
        switch (result.term) {
            .Exited => |code| if (code != 0) {
                if (result.stderr.len != 0) {
                    std.log.err("update '{s}': zig cc stderr:\n{s}", .{
                        update.name, result.stderr,
                    });
                }
                fatal("update '{s}': zig cc for '{s}' failed with code {d}", .{
                    update.name, c_path, code,
                });
            },
            .Signal, .Stopped, .Unknown => {
                if (result.stderr.len != 0) {
                    std.log.err("update '{s}': zig cc stderr:\n{s}", .{
                        update.name, result.stderr,
                    });
                }
                fatal("update '{s}': zig cc for '{s}' terminated unexpectedly", .{
                    update.name, c_path,
                });
            },
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
        var updates: std.ArrayListUnmanaged(Update) = .empty;
        var changes: std.ArrayListUnmanaged(FullContents) = .empty;
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
