const std = @import("std");
const builtin = @import("builtin");

pub fn main() void {
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;

    for (builtin.test_functions) |test_fn| {
        if (test_fn.func()) |_| {
            ok_count += 1;
        } else |err| switch (err) {
            error.SkipZigTest => skip_count += 1,
            else => fail_count += 1,
        }
    }
    if (ok_count != 1 or skip_count != 1 or fail_count != 1) {
        std.process.exit(1);
    }
}
