//! Default test runner for unit tests.
const std = @import("std");
const io = std.io;
const builtin = @import("builtin");

pub const std_options = struct {
    pub const io_mode: io.Mode = builtin.test_io_mode;
    pub const logFn = log;
};

var log_err_count: usize = 0;
var cmdline_buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&cmdline_buffer);

const Mode = enum {
    listen,
    terminal,
    panic_test,
};

fn callError(args: [][:0]u8) noreturn {
    std.debug.print("invalid cli arguments:\n", .{});
    for (args) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
    @panic("call error");
}

pub fn main() void {
    if (builtin.zig_backend == .stage2_aarch64) {
        return mainSimple() catch @panic("test failure");
    }

    const args = std.process.argsAlloc(fba.allocator()) catch
        @panic("unable to parse command line args");

    var i: u32 = 1;
    var test_i: ?u64 = null;
    var mode: Mode = .terminal;

    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--listen=-")) {
            mode = .listen;
        } else if (std.mem.eql(u8, args[i], "--test_panic_index")) {
            i += 1;
            if (i < args.len) {
                test_i = std.fmt.parseInt(u64, args[i], 10) catch {
                    callError(args);
                };
                mode = .panic_test;
                std.testing.is_panic_parentproc = false;
            } else {
                callError(args);
            }
        } else {
            callError(args);
        }
    }

    switch (mode) {
        .listen => return mainServer() catch @panic("internal test runner failure"),
        .terminal => return mainTerminal(args),
        .panic_test => return panicTest(test_i.?),
    }
}

fn mainServer() !void {
    var server = try std.zig.Server.init(.{
        .gpa = fba.allocator(),
        .in = std.io.getStdIn(),
        .out = std.io.getStdOut(),
        .zig_version = builtin.zig_version_string,
    });
    defer server.deinit();

    while (true) {
        const hdr = try server.receiveMessage();
        switch (hdr.tag) {
            .exit => {
                return std.process.exit(0);
            },
            .query_test_metadata => {
                std.testing.allocator_instance = .{};
                defer if (std.testing.allocator_instance.deinit() == .leak) {
                    @panic("internal test runner memory leak");
                };

                var string_bytes: std.ArrayListUnmanaged(u8) = .{};
                defer string_bytes.deinit(std.testing.allocator);
                try string_bytes.append(std.testing.allocator, 0); // Reserve 0 for null.

                const test_fns = builtin.test_functions;
                const names = try std.testing.allocator.alloc(u32, test_fns.len);
                defer std.testing.allocator.free(names);
                const async_frame_sizes = try std.testing.allocator.alloc(u32, test_fns.len);
                defer std.testing.allocator.free(async_frame_sizes);
                const expected_panic_msgs = try std.testing.allocator.alloc(u32, test_fns.len);
                defer std.testing.allocator.free(expected_panic_msgs);

                for (test_fns, names, async_frame_sizes, expected_panic_msgs) |test_fn, *name, *async_frame_size, *expected_panic_msg| {
                    name.* = @as(u32, @intCast(string_bytes.items.len));
                    try string_bytes.ensureUnusedCapacity(std.testing.allocator, test_fn.name.len + 1);
                    string_bytes.appendSliceAssumeCapacity(test_fn.name);
                    string_bytes.appendAssumeCapacity(0);

                    async_frame_size.* = @as(u32, @intCast(test_fn.async_frame_size orelse 0));
                    expected_panic_msg.* = 0;
                }

                try server.serveTestMetadata(.{
                    .names = names,
                    .async_frame_sizes = async_frame_sizes,
                    .expected_panic_msgs = expected_panic_msgs,
                    .string_bytes = string_bytes.items,
                });
            },

            .run_test => {
                std.testing.allocator_instance = .{};
                log_err_count = 0;
                const index = try server.receiveBody_u32();
                const test_fn = builtin.test_functions[index];
                if (test_fn.async_frame_size != null)
                    @panic("TODO test runner implement async tests");
                var fail = false;
                var skip = false;
                var leak = false;
                test_fn.func() catch |err| switch (err) {
                    error.SkipZigTest => skip = true,
                    else => {
                        fail = true;
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                        }
                    },
                };
                leak = std.testing.allocator_instance.deinit() == .leak;
                try server.serveTestResults(.{
                    .index = index,
                    .flags = .{
                        .fail = fail,
                        .skip = skip,
                        .leak = leak,
                        .log_err_count = std.math.lossyCast(std.meta.FieldType(
                            std.zig.Server.Message.TestResults.Flags,
                            .log_err_count,
                        ), log_err_count),
                    },
                });
            },

            else => {
                std.debug.print("unsupported message: {x}", .{@intFromEnum(hdr.tag)});
                std.process.exit(1);
            },
        }
    }
}

// TODO
// - [ ] has test_i:
//   * spawn and compare specific function
//   * compare result: if returning from execution => @panic("FoundNoPanicInTest");
// - [ ] not test_i:
//   * iterate through all functions
//   * compare result: compare execution result with special case for panic msg "FoundNoPanicInTest"

fn mainTerminal(args: [][:0]const u8) void {
    var test_i_buf: [20]u8 = undefined;
    // TODO make environment buffer size configurable and use a sane default
    // Tradeoff: waste stack space or allocate on every panic test
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;
    var progress = std.Progress{
        .dont_print_on_dumb = true,
    };
    const root_node = progress.start("Test", test_fn_list.len);
    const have_tty = progress.terminal != null and
        (progress.supports_ansi_escape_codes or progress.is_windows_terminal);

    var async_frame_buffer: []align(builtin.target.stackAlignment()) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};
    var leaks: usize = 0;
    for (test_fn_list, 0..) |test_fn, i| {
        std.testing.allocator_instance = .{};
        defer {
            if (std.testing.allocator_instance.deinit() == .leak) {
                leaks += 1;
            }
        }
        std.testing.log_level = .warn;

        var test_node = root_node.start(test_fn.name, 0);
        test_node.activate();
        progress.refresh();
        if (!have_tty) {
            std.debug.print("{d}/{d} {s}... ", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        const result = if (test_fn.async_frame_size) |size| switch (std.options.io_mode) {
            .evented => blk: {
                if (async_frame_buffer.len < size) {
                    std.heap.page_allocator.free(async_frame_buffer);
                    async_frame_buffer = std.heap.page_allocator.alignedAlloc(u8, std.Target.stack_align, size) catch @panic("out of memory");
                }
                const casted_fn = @as(fn () callconv(.Async) anyerror!void, @ptrCast(test_fn.func));
                break :blk await @asyncCall(async_frame_buffer, {}, casted_fn, .{});
            },
            .blocking => {
                skip_count += 1;
                test_node.end();
                progress.log("SKIP (async test)\n", .{});
                continue;
            },
        } else test_fn.func();
        if (result) |_| {
            ok_count += 1;
            test_node.end();
            if (!have_tty) std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                progress.log("SKIP\n", .{});
                test_node.end();
            },
            error.SpawnZigTest => {
                progress.log("error.SpawnZigTest\n", .{});
                if (!std.testing.can_panic_test)
                    @panic("Found error.SpawnZigTest without panic test capabilities.");
                if (std.testing.panic_msg == null)
                    @panic("Panic test expects `panic_msg` to be set. Use std.testing.spawnExpectPanic().");

                const test_i_written = std.fmt.bufPrint(&test_i_buf, "{d}", .{i}) catch unreachable;
                var child_proc = std.ChildProcess.init(
                    &.{ args[0], "--test_panic_index", test_i_written },
                    std.testing.allocator,
                );
                progress.log("spawning '{s} {s} {s}'\n", .{ args[0], "--test_panic_index", test_i_written });

                child_proc.stdin_behavior = .Ignore;
                child_proc.stdout_behavior = .Pipe;
                child_proc.stderr_behavior = .Pipe;
                child_proc.spawn() catch |spawn_err| {
                    progress.log("FAIL spawn ({s})\n", .{@errorName(spawn_err)});
                    fail_count += 1;
                    test_node.end();
                    continue;
                };

                var stdout = std.ArrayList(u8).init(std.testing.allocator);
                defer stdout.deinit();
                var stderr = std.ArrayList(u8).init(std.testing.allocator);
                defer stderr.deinit();
                // child_process.zig: max_output_bytes: usize = 50 * 1024,
                child_proc.collectOutput(&stdout, &stderr, 50 * 1024) catch |collect_err| {
                    progress.log("FAIL collect ({s})\n", .{@errorName(collect_err)});
                    fail_count += 1;
                    test_node.end();
                    continue;
                };
                const term = child_proc.wait() catch |wait_err| {
                    child_proc.cleanupStreams();
                    progress.log("FAIL wait_error (exit_status: {d})\n", .{@errorName(wait_err)});
                    fail_count += 1;
                    test_node.end();
                    continue;
                };
                switch (term) {
                    .Exited => |code| {
                        progress.log("FAIL term exited, status: {})\nstdout: ({s})\nstderr: ({s})\n", .{ code, stdout.items, stderr.items });
                        fail_count += 1;
                        test_node.end();
                        continue;
                    },
                    .Signal => |code| {
                        progress.log("Signal: {d}\n", .{code});
                        // assert: panic message format: 'XYZ thread thread_id panic: msg'
                        // Any signal can be returned on panic, if a custom signal
                        // or panic handler was installed as part of the unit test.
                        var pos_eol: usize = 0;
                        var found_eol: bool = false;
                        while (pos_eol < stderr.items.len) : (pos_eol += 1) {
                            if (stderr.items[pos_eol] == '\n') {
                                found_eol = true;
                                break;
                            }
                        }

                        if (!found_eol) {
                            progress.log("FAIL no end of line in panic format\nstdout: ({s})\nstderr: ({s})\n", .{ stdout.items, stderr.items });
                            fail_count += 1;
                            test_node.end();
                            continue;
                        }

                        var it = std.mem.tokenize(u8, stderr.items[0..pos_eol], " ");
                        var parsed_panic_msg = false;
                        while (it.next()) |word| { // 'thread thread_id panic: msg'
                            if (!std.mem.eql(u8, word, "thread")) continue;
                            const thread_id = it.next();
                            if (thread_id == null) continue;
                            _ = std.fmt.parseInt(u64, thread_id.?, 10) catch continue;
                            const panic_txt = it.next();
                            if (panic_txt == null) continue;
                            if (!std.mem.eql(u8, panic_txt.?, "panic:")) continue;
                            const panic_msg = it.next();
                            if (panic_msg == null) continue;
                            const panic_msg_start = it.index - panic_msg.?.len;
                            const len_exp_panic_msg = std.mem.len(@as([*:0]u8, std.testing.panic_msg.?[0..]));
                            const expected_panic_msg = std.testing.panic_msg.?[0..len_exp_panic_msg];
                            const panic_msg_end = panic_msg_start + expected_panic_msg.len;
                            if (panic_msg_end > pos_eol) break;

                            parsed_panic_msg = true;
                            const current_panic_msg = stderr.items[panic_msg_start..panic_msg_end];

                            if (!std.mem.eql(u8, "SKIP (async test)", current_panic_msg) and !std.mem.eql(u8, expected_panic_msg, current_panic_msg)) {
                                progress.log("FAIL expected_panic_msg: '{s}', got: '{s}'\n", .{ expected_panic_msg, current_panic_msg });
                                std.testing.panic_msg = null;
                                fail_count += 1;
                                test_node.end();
                                break;
                            }
                            std.testing.panic_msg = null;
                            ok_count += 1;
                            test_node.end();
                            if (!have_tty) std.debug.print("OK\n", .{});
                            break;
                        }
                        if (!parsed_panic_msg) {
                            progress.log("FAIL invalid panic_msg format expect 'XYZ thread thread_id panic: msg'\nstdout: ({s})\nstderr: ({s})\n", .{ stdout.items, stderr.items });
                            fail_count += 1;
                            test_node.end();
                            continue;
                        }
                    },
                    .Stopped => |code| {
                        fail_count += 1;
                        progress.log("FAIL stopped, status: ({d})\nstdout: ({s})\nstderr: ({s})\n", .{ code, stdout.items, stderr.items });
                        test_node.end();
                        continue;
                    },
                    .Unknown => |code| {
                        fail_count += 1;
                        progress.log("FAIL unknown, status: ({d})\nstdout: ({s})\nstderr: ({s})\n", .{ code, stdout.items, stderr.items });
                        test_node.end();
                        continue;
                    },
                }
            },
            else => {
                fail_count += 1;
                progress.log("FAIL unexpected error ({s})\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                test_node.end();
            },
        }
    }
    root_node.end();
    if (ok_count == test_fn_list.len) {
        std.debug.print("All {d} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{d} passed; {d} skipped; {d} failed.\n", .{ ok_count, skip_count, fail_count });
    }
    if (log_err_count != 0) {
        std.debug.print("{d} errors were logged.\n", .{log_err_count});
    }
    if (leaks != 0) {
        std.debug.print("{d} tests leaked memory.\n", .{leaks});
    }
    if (leaks != 0 or log_err_count != 0 or fail_count != 0) {
        std.process.exit(1);
    }
}

fn panicTest(test_i: u64) void {
    const test_fn_list = builtin.test_functions;
    var async_frame_buffer: []align(std.Target.stack_align) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};
    {
        std.testing.allocator_instance = .{};
        // custom panic handler to restore to save state and prevent memory
        // leakage is out of scope, so ignore memory leaks
        defer {
            if (std.testing.allocator_instance.deinit() == .leak) {
                @panic("internal test runner memory leak");
            }
        }
        std.testing.log_level = .warn;
        const result = if (test_fn_list[test_i].async_frame_size) |size| switch (std.options.io_mode) {
            .evented => blk: {
                if (async_frame_buffer.len < size) {
                    std.heap.page_allocator.free(async_frame_buffer);
                    async_frame_buffer = std.heap.page_allocator.alignedAlloc(u8, std.Target.stack_align, size) catch @panic("out of memory");
                }
                const casted_fn = @ptrCast(fn () callconv(.Async) anyerror!void, test_fn_list[test_i].func);
                break :blk await @asyncCall(async_frame_buffer, {}, casted_fn, .{});
            },
            .blocking => @panic("SKIP (async test)"),
        } else test_fn_list[test_i].func();

        if (result) {
            std.os.exit(0);
        } else |err| {
            std.debug.print("FAIL unexpected error ({s})\n", .{@errorName(err)});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
        }
    }
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(message_level) <= @intFromEnum(std.log.Level.err)) {
        log_err_count +|= 1;
    }
    if (@intFromEnum(message_level) <= @intFromEnum(std.testing.log_level)) {
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

/// Simpler main(), exercising fewer language features, so that
/// work-in-progress backends can handle it.
pub fn mainSimple() anyerror!void {
    const enable_print = false;
    const print_all = false;

    var passed: u64 = 0;
    var skipped: u64 = 0;
    var failed: u64 = 0;
    const stderr = if (enable_print) std.io.getStdErr() else {};
    for (builtin.test_functions) |test_fn| {
        if (enable_print and print_all) {
            stderr.writeAll(test_fn.name) catch {};
            stderr.writeAll("... ") catch {};
        }
        test_fn.func() catch |err| {
            if (enable_print and !print_all) {
                stderr.writeAll(test_fn.name) catch {};
                stderr.writeAll("... ") catch {};
            }
            if (err != error.SkipZigTest) {
                if (enable_print) stderr.writeAll("FAIL\n") catch {};
                failed += 1;
                if (!enable_print) return err;
                continue;
            }
            if (enable_print) stderr.writeAll("SKIP\n") catch {};
            skipped += 1;
            continue;
        };
        if (enable_print and print_all) stderr.writeAll("PASS\n") catch {};
        passed += 1;
    }
    if (enable_print) {
        stderr.writer().print("{} passed, {} skipped, {} failed\n", .{ passed, skipped, failed }) catch {};
        if (failed != 0) std.process.exit(1);
    }
}
