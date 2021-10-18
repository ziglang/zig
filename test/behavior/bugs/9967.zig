const std = @import("std");

test "nested breaks to same labeled block" {
    const a = blk: {
        break :blk break :blk @as(u32, 1);
    };
    try std.testing.expectEqual(a, 1);
}
