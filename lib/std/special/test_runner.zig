const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.test_functions;

pub fn main() anyerror!void {
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
        if (test_fn.func()) |_| {
            ok_count += 1;
            test_node.end();
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                test_node.end();
                progress.log("{}...SKIP\n", test_fn.name);
            },
            else => {
                progress.log("");
                return err;
            },
        }
    }
    root_node.end();
    if (ok_count != test_fn_list.len) {
        std.debug.warn("{} passed; {} skipped.\n", ok_count, skip_count);
    }
}
