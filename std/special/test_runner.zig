const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.__zig_test_fn_slice;
const warn = std.debug.warn;

pub fn main() -> %void {
    for (test_fn_list) |test_fn, i| {
        warn("Test {}/{} {}...", i + 1, test_fn_list.len, test_fn.name);

        if (builtin.is_test) {
            test_fn.func() catch unreachable;
        } else {
            test_fn.func() catch |err| {
                warn("{}\n", err);
                return err;
            };
        }

        warn("OK\n");
    }
}
