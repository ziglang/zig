const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@popCount integers" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testPopCountIntegers();
    try testPopCountIntegers();
}

test "@popCount 128bit integer" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime {
        try expect(@popCount(@as(u128, 0b11111111000110001100010000100001000011000011100101010001)) == 24);
        try expect(@popCount(@as(i128, 0b11111111000110001100010000100001000011000011100101010001)) == 24);
    }

    {
        var x: u128 = 0b11111111000110001100010000100001000011000011100101010001;
        try expect(@popCount(x) == 24);
    }

    try expect(@popCount(@as(i128, 0b11111111000110001100010000100001000011000011100101010001)) == 24);
}

fn testPopCountIntegers() !void {
    {
        var x: u32 = 0xffffffff;
        try expect(@popCount(x) == 32);
    }
    {
        var x: u5 = 0x1f;
        try expect(@popCount(x) == 5);
    }
    {
        var x: u32 = 0xaa;
        try expect(@popCount(x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(x) == 16);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(x) == 16);
    }
    {
        var x: i16 = -1;
        try expect(@popCount(x) == 16);
    }
    {
        var x: i8 = -120;
        try expect(@popCount(x) == 2);
    }
    comptime {
        try expect(@popCount(@bitCast(u8, @as(i8, -120))) == 2);
    }
}

test "@popCount vectors" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testPopCountVectors();
    try testPopCountVectors();
}

fn testPopCountVectors() !void {
    {
        var x: @Vector(8, u32) = [1]u32{0xffffffff} ** 8;
        const expected = [1]u6{32} ** 8;
        const result: [8]u6 = @popCount(x);
        try expect(std.mem.eql(u6, &expected, &result));
    }
    {
        var x: @Vector(8, i16) = [1]i16{-1} ** 8;
        const expected = [1]u5{16} ** 8;
        const result: [8]u5 = @popCount(x);
        try expect(std.mem.eql(u5, &expected, &result));
    }
}
