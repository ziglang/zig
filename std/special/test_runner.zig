const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.__zig_test_fn_slice;
const warn = std.debug.warn;

pub fn main() -> %void {
    for (test_fn_list) |test_fn, i| {
        warn("Test {}/{} {}...", i + 1, test_fn_list.len, test_fn.name);

        try test_fn.func();

        warn("OK\n");
    }
}
