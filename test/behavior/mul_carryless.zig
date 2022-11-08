const std = @import("std");
const u64x2 = std.meta.Vector(2, u64);

test "carryless mul" {
    const S = struct {
        fn doTheTest() !void {
            const a = 0b10100010;
            const b = 0b10010110;
            const expected = @as(u64, 0b101100011101100);
            const av: u64x2 = .{ a, 0 };
            const bv: u64x2 = .{ b, 0 };
            const r = @mulCarryless(av, bv, @as(u8, 0));
            try std.testing.expectEqual(expected, r[0]);
        }
    };
    try S.doTheTest();
    // comptime try S.doTheTest();
}
