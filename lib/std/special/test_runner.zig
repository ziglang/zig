const std = @import("std");
const io = std.io;
const builtin = @import("builtin");

pub const io_mode: io.Mode = builtin.test_io_mode;

var log_err_count: usize = 0;

var args_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

/// The list of test arguments passed to the test runner via `--test-arg`
pub var test_args = std.StringHashMap([]const u8).init(args_allocator.allocator());

fn nextArg(args: *std.process.ArgIterator) ?[]const u8 {
    return args.next(args_allocator.allocator()) catch @panic("Out of memory while parsing args.");
}

fn processArgs() void {
    var args = std.process.argsWithAllocator(args_allocator.allocator()) catch |err| {
        std.debug.panic("Error creating os args iterator: {}", .{err});
    };
    defer args.deinit();

    const test_exe_path = nextArg(&args) orelse @panic("No self executable in arguments");

    while (nextArg(&args)) |arg| {
        if (std.mem.eql(u8, arg, "--test-arg")) {
            const key = nextArg(&args) orelse @panic("--test-arg requires two arguments, but none were provided.");
            const value = nextArg(&args) orelse @panic("--test-arg requires two arguments, but only one was provided.");
            const gop = test_args.getOrPut(key) catch @panic("Out of memory while parsing args, in test_args insertion.");
            if (gop.found_existing) std.debug.panic("test argument was specified twice: {s}.", .{key});
            gop.value_ptr.* = value;
        } else if (std.mem.eql(u8, arg, "--help")) {
            const exe_name = std.fs.path.basename(test_exe_path);
            std.debug.print("Usage: {s} [options]\n{s}", .{
                exe_name,
                \\
                \\Options:
                \\    -h, --help                  Print this help and exit
                \\    --test-arg <key> <value>    Specify an argument that can be retrieved from std.testing.getTestArgument(..)
                \\
            });
            std.process.exit(1);
        } else {
            std.debug.panic("Unknown argument: {s}. Use --help to see usage.", .{arg});
        }
    }
}

pub fn main() void {
    if (builtin.zig_is_stage2) {
        return main2() catch @panic("test failure");
    }
    processArgs();
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;
    var progress = std.Progress{
        .dont_print_on_dumb = true,
    };
    const root_node = progress.start("Test", test_fn_list.len) catch |err| switch (err) {
        // TODO still run tests in this case
        error.TimerUnsupported => @panic("timer unsupported"),
    };
    const have_tty = progress.terminal != null and progress.supports_ansi_escape_codes;

    var async_frame_buffer: []align(std.Target.stack_align) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};

    var leaks: usize = 0;
    for (test_fn_list) |test_fn, i| {
        std.testing.allocator_instance = .{};
        defer {
            if (std.testing.allocator_instance.deinit()) {
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
        const result = if (test_fn.async_frame_size) |size| switch (io_mode) {
            .evented => blk: {
                if (async_frame_buffer.len < size) {
                    std.heap.page_allocator.free(async_frame_buffer);
                    async_frame_buffer = std.heap.page_allocator.alignedAlloc(u8, std.Target.stack_align, size) catch @panic("out of memory");
                }
                const casted_fn = @ptrCast(fn () callconv(.Async) anyerror!void, test_fn.func);
                break :blk await @asyncCall(async_frame_buffer, {}, casted_fn, .{});
            },
            .blocking => {
                skip_count += 1;
                test_node.end();
                progress.log("{s}... SKIP (async test)\n", .{test_fn.name});
                if (!have_tty) std.debug.print("SKIP (async test)\n", .{});
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
                test_node.end();
                progress.log("{s}... SKIP\n", .{test_fn.name});
                if (!have_tty) std.debug.print("SKIP\n", .{});
            },
            else => {
                fail_count += 1;
                test_node.end();
                progress.log("{s}... FAIL ({s})\n", .{ test_fn.name, @errorName(err) });
                if (!have_tty) std.debug.print("FAIL ({s})\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
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

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@enumToInt(message_level) <= @enumToInt(std.log.Level.err)) {
        log_err_count += 1;
    }
    if (@enumToInt(message_level) <= @enumToInt(std.testing.log_level)) {
        std.debug.print("[{s}] ({s}): " ++ format ++ "\n", .{ @tagName(scope), @tagName(message_level) } ++ args);
    }
}

pub fn main2() anyerror!void {
    var bad = false;
    // Simpler main(), exercising fewer language features, so that stage2 can handle it.
    for (builtin.test_functions) |test_fn| {
        test_fn.func() catch |err| {
            if (err != error.SkipZigTest) {
                bad = true;
            }
        };
    }
    if (bad) {
        return error.TestsFailed;
    }
}
