const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@popCount integers" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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
    {
        var x: u128 = 0b11111111000110001100010000100001000011000011100101010001;
        try expect(@popCount(u128, x) == 24);
    }
    comptime {
        try expect(@popCount(u8, @bitCast(u8, @as(i8, -120))) == 2);
    }
    comptime {
        try expect(@popCount(i128, @as(i128, 0b11111111000110001100010000100001000011000011100101010001)) == 24);
    }
}

test "@popCount vectors" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    comptime try testPopCountVectors();
    try testPopCountVectors();
}

fn testPopCountVectors() !void {
    {
        var x: @Vector(8, u32) = [1]u32{0xffffffff} ** 8;
        const expected = [1]u6{32} ** 8;
        const result: [8]u6 = @popCount(u32, x);
        try expect(std.mem.eql(u6, &expected, &result));
    }
    {
        var x: @Vector(8, i16) = [1]i16{-1} ** 8;
        const expected = [1]u5{16} ** 8;
        const result: [8]u5 = @popCount(i16, x);
        try expect(std.mem.eql(u5, &expected, &result));
    }
}
