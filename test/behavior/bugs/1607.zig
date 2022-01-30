const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const a = [_]u8{ 1, 2, 3 };

fn checkAddress(s: []const u8) !void {
    for (s) |*i, j| {
        try testing.expect(i == &a[j]);
    }
}

test "slices pointing at the same address as global array." {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    try checkAddress(&a);
    comptime try checkAddress(&a);
}
