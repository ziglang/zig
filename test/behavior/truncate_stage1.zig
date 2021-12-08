const std = @import("std");
const expect = std.testing.expect;

test "truncate on vectors" {
    const S = struct {
        fn doTheTest() !void {
            var v1: @Vector(4, u16) = .{ 0xaabb, 0xccdd, 0xeeff, 0x1122 };
            var v2 = @truncate(u8, v1);
            try expect(std.mem.eql(u8, &@as([4]u8, v2), &[4]u8{ 0xbb, 0xdd, 0xff, 0x22 }));
        }
    };
    try S.doTheTest();
}
