const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const a = [_]u8{ 1, 2, 3 };

fn checkAddress(s: []const u8) !void {
    for (s, 0..) |*i, j| {
        try testing.expect(i == &a[j]);
    }
}

test "slices pointing at the same address as global array." {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    try checkAddress(&a);
    comptime try checkAddress(&a);
}
