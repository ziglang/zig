const std = @import("std");
const testing = std.testing;

const a = [_]u8{ 1, 2, 3 };

fn checkAddress(s: []const u8) void {
    for (s) |*i, j| {
        testing.expect(i == &a[j]);
    }
}

test "slices pointing at the same address as global array." {
    checkAddress(&a);
    comptime checkAddress(&a);
}
