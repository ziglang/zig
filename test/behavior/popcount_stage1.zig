const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Vector = std.meta.Vector;

test "@popCount vectors" {
    comptime try testPopCountVectors();
    try testPopCountVectors();
}

fn testPopCountVectors() !void {
    {
        var x: Vector(8, u32) = [1]u32{0xffffffff} ** 8;
        const expected = [1]u6{32} ** 8;
        const result: [8]u6 = @popCount(u32, x);
        try expect(std.mem.eql(u6, &expected, &result));
    }
    {
        var x: Vector(8, i16) = [1]i16{-1} ** 8;
        const expected = [1]u5{16} ** 8;
        const result: [8]u5 = @popCount(i16, x);
        try expect(std.mem.eql(u5, &expected, &result));
    }
}
