const std = @import("std");
const io = std.io;
const builtin = @import("builtin");

pub const io_mode: io.Mode = builtin.test_io_mode;

var log_err_count: usize = 0;

pub fn main() anyerror!void {
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var progress = std.Progress{};
    const root_node = progress.start("Test", test_fn_list.len) catch |err| switch (err) {
        // TODO still run tests in this case
        error.TimerUnsupported => @panic("timer unsupported"),
    };

    var async_frame_buffer: []align(std.Target.stack_align) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};

    var leaks: usize = 0;
    for (test_fn_list) |test_fn, i| {
        std.testing.allocator_instance = std.heap.GeneralPurposeAllocator(.{}){};
        defer {
            if (std.testing.allocator_instance.deinit()) {
                leaks += 1;
            }
        }
        std.testing.log_level = .warn;

        var test_node = root_node.start(test_fn.name, null);
        test_node.activate();
        progress.refresh();
        if (progress.terminal == null) {
            std.debug.print("{}/{} {}...", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        const result = if (test_fn.async_frame_size) |size| switch (io_mode) {
            .evented => blk: {
                if (async_frame_buffer.len < size) {
                    std.heap.page_allocator.free(async_frame_buffer);
                    async_frame_buffer = try std.heap.page_allocator.alignedAlloc(u8, std.Target.stack_align, size);
                }
                const casted_fn = @ptrCast(fn () callconv(.Async) anyerror!void, test_fn.func);
                break :blk await @asyncCall(async_frame_buffer, {}, casted_fn, .{});
            },
            .blocking => {
                skip_count += 1;
                test_node.end();
                progress.log("{}...SKIP (async test)\n", .{test_fn.name});
                if (progress.terminal == null) std.debug.print("SKIP (async test)\n", .{});
                continue;
            },
        } else test_fn.func();
        if (result) |_| {
            ok_count += 1;
            test_node.end();
            if (progress.terminal == null) std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                test_node.end();
                progress.log("{}...SKIP\n", .{test_fn.name});
                if (progress.terminal == null) std.debug.print("SKIP\n", .{});
            },
            else => {
                progress.log("", .{});
                return err;
            },
        }
    }
    root_node.end();
    if (ok_count == test_fn_list.len) {
        std.debug.print("All {} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{} passed; {} skipped.\n", .{ ok_count, skip_count });
    }
    if (log_err_count != 0) {
        std.debug.print("{} errors were logged.\n", .{log_err_count});
    }
    if (leaks != 0) {
        std.debug.print("{} tests leaked memory.\n", .{ok_count});
    }
    if (leaks != 0 or log_err_count != 0) {
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
        std.debug.print("[{}] ({}): " ++ format, .{ @tagName(scope), @tagName(message_level) } ++ args);
    }
}
