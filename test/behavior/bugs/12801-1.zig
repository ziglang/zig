const std = @import("std");
const builtin = @import("builtin");

comptime capacity: fn () u64 = capacity_,
fn capacity_() u64 {
    return 64;
}

test {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try std.testing.expect((@This(){}).capacity() == 64);
}
