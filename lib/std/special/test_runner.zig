const std = @import("std");
const io = std.io;
const builtin = @import("builtin");

pub fn main() anyerror!void {
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var progress = std.Progress{};
    const root_node = progress.start("Test", test_fn_list.len) catch |err| switch (err) {
        // TODO still run tests in this case
        error.TimerUnsupported => @panic("timer unsupported"),
    };

    for (test_fn_list) |test_fn, i| {
        var test_node = root_node.start(test_fn.name, null);
        test_node.activate();
        progress.refresh();
        if (progress.terminal == null) {
            std.debug.warn("{}/{} {}...", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        if (test_fn.func()) |_| {
            ok_count += 1;
            test_node.end();
            if (progress.terminal == null) std.debug.warn("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                test_node.end();
                progress.log("{}...SKIP\n", .{test_fn.name});
                if (progress.terminal == null) std.debug.warn("SKIP\n", .{});
            },
            else => {
                progress.log("", .{});
                return err;
            },
        }
    }
    root_node.end();
    if (ok_count == test_fn_list.len) {
        std.debug.warn("All {} tests passed.\n", .{ok_count});
    } else {
        std.debug.warn("{} passed; {} skipped.\n", .{ ok_count, skip_count });
    }
}
