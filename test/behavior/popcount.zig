const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Vector = std.meta.Vector;

test "@popCount integers" {
    comptime try testPopCountIntegers();
    try testPopCountIntegers();
}

fn testPopCountIntegers() !void {
    {
        var x: u32 = 0xffffffff;
        try expect(@popCount(u32, x) == 32);
    }
    {
        var x: u5 = 0x1f;
        try expect(@popCount(u5, x) == 5);
    }
    {
        var x: u32 = 0xaa;
        try expect(@popCount(u32, x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(u32, x) == 16);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(u32, x) == 16);
    }
    {
        var x: i16 = -1;
        try expect(@popCount(i16, x) == 16);
    }
    {
        var x: i8 = -120;
        try expect(@popCount(i8, x) == 2);
    }
    comptime {
        try expect(@popCount(u8, @bitCast(u8, @as(i8, -120))) == 2);
    }
    comptime {
        try expect(@popCount(i128, 0b11111111000110001100010000100001000011000011100101010001) == 24);
    }
}

test "@popCount vectors" {
    comptime try testPopCountVectors();
    try testPopCountVectors();
}

fn testPopCountVectors() !void {
    {
        var x: Vector(8, u32) = [1]u32{0xffffffff} ** 8;
        try expectEqual([1]u6{32} ** 8, @as([8]u6, @popCount(u32, x)));
    }
    {
        var x: Vector(8, i16) = [1]i16{-1} ** 8;
        try expectEqual([1]u5{16} ** 8, @as([8]u5, @popCount(i16, x)));
    }
}
