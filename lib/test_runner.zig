const std = @import("std");
const io = std.io;
const builtin = @import("builtin");

pub const std_options = struct {
    pub const io_mode: io.Mode = builtin.test_io_mode;
    pub const logFn = log;
};

var log_err_count: usize = 0;

pub fn main() void {
    if (builtin.zig_backend != .stage1 and
        builtin.zig_backend != .stage2_llvm and
        builtin.zig_backend != .stage2_c)
    {
        return main2() catch @panic("test failure");
    }
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

    var async_frame_buffer: []align(std.Target.stack_align) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};

    var leaks: usize = 0;
    for (test_fn_list, 0..) |test_fn, i| {
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
        const result = if (test_fn.async_frame_size) |size| switch (std.options.io_mode) {
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
            else => {
                fail_count += 1;
                progress.log("FAIL ({s})\n", .{@errorName(err)});
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
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

pub fn main2() anyerror!void {
    var skipped: usize = 0;
    var failed: usize = 0;
    // Simpler main(), exercising fewer language features, so that stage2 can handle it.
    for (builtin.test_functions) |test_fn| {
        test_fn.func() catch |err| {
            if (err != error.SkipZigTest) {
                failed += 1;
            } else {
                skipped += 1;
            }
        };
    }
    if (builtin.zig_backend == .stage2_wasm or
        builtin.zig_backend == .stage2_x86_64 or
        builtin.zig_backend == .stage2_aarch64 or
        builtin.zig_backend == .stage2_llvm or
        builtin.zig_backend == .stage2_c)
    {
        const passed = builtin.test_functions.len - skipped - failed;
        const stderr = std.io.getStdErr();
        writeInt(stderr, passed) catch {};
        stderr.writeAll(" passed; ") catch {};
        writeInt(stderr, skipped) catch {};
        stderr.writeAll(" skipped; ") catch {};
        writeInt(stderr, failed) catch {};
        stderr.writeAll(" failed.\n") catch {};
    }
    if (failed != 0) {
        return error.TestsFailed;
    }
}

fn writeInt(stderr: std.fs.File, int: usize) anyerror!void {
    const base = 10;
    var buf: [100]u8 = undefined;
    var a: usize = int;
    var index: usize = buf.len;
    while (true) {
        const digit = a % base;
        index -= 1;
        buf[index] = std.fmt.digitToChar(@intCast(u8, digit), .lower);
        a /= base;
        if (a == 0) break;
    }
    const slice = buf[index..];
    try stderr.writeAll(slice);
}
