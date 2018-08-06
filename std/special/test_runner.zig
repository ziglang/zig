const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.__zig_test_fn_slice;
const warn = std.debug.warn;

pub fn main() !void {
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    for (test_fn_list) |test_fn, i| {
        warn("Test {}/{} {}...", i + 1, test_fn_list.len, test_fn.name);

        if (test_fn.func()) |_| {
            ok_count += 1;
            warn("OK\n");
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                warn("SKIP\n");
            },
            else => return err,
        }
    }
    if (ok_count == test_fn_list.len) {
        warn("All tests passed.\n");
    } else {
        warn("{} passed; {} skipped.\n", ok_count, skip_count);
    }
}
