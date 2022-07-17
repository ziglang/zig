const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const minInt = std.math.minInt;

test "@bitReverse large exotic integer" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    // Currently failing on stage1 for big-endian targets
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    try expect(@bitReverse(u95, @as(u95, 0x123456789abcdef111213141)) == 0x4146424447bd9eac8f351624);
}

test "@bitReverse" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    comptime try testBitReverse();
    try testBitReverse();
}

fn testBitReverse() !void {
    // using comptime_ints, unsigned
    try expect(@bitReverse(u0, @as(u0, 0)) == 0);
    try expect(@bitReverse(u5, @as(u5, 0x12)) == 0x9);
    try expect(@bitReverse(u8, @as(u8, 0x12)) == 0x48);
    try expect(@bitReverse(u16, @as(u16, 0x1234)) == 0x2c48);
    try expect(@bitReverse(u24, @as(u24, 0x123456)) == 0x6a2c48);
    try expect(@bitReverse(u32, @as(u32, 0x12345678)) == 0x1e6a2c48);
    try expect(@bitReverse(u40, @as(u40, 0x123456789a)) == 0x591e6a2c48);
    try expect(@bitReverse(u48, @as(u48, 0x123456789abc)) == 0x3d591e6a2c48);
    try expect(@bitReverse(u56, @as(u56, 0x123456789abcde)) == 0x7b3d591e6a2c48);
    try expect(@bitReverse(u64, @as(u64, 0x123456789abcdef1)) == 0x8f7b3d591e6a2c48);
    try expect(@bitReverse(u96, @as(u96, 0x123456789abcdef111213141)) == 0x828c84888f7b3d591e6a2c48);
    try expect(@bitReverse(u128, @as(u128, 0x123456789abcdef11121314151617181)) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using runtime uints, unsigned
    var num0: u0 = 0;
    try expect(@bitReverse(u0, num0) == 0);
    var num5: u5 = 0x12;
    try expect(@bitReverse(u5, num5) == 0x9);
    var num8: u8 = 0x12;
    try expect(@bitReverse(u8, num8) == 0x48);
    var num16: u16 = 0x1234;
    try expect(@bitReverse(u16, num16) == 0x2c48);
    var num24: u24 = 0x123456;
    try expect(@bitReverse(u24, num24) == 0x6a2c48);
    var num32: u32 = 0x12345678;
    try expect(@bitReverse(u32, num32) == 0x1e6a2c48);
    var num40: u40 = 0x123456789a;
    try expect(@bitReverse(u40, num40) == 0x591e6a2c48);
    var num48: u48 = 0x123456789abc;
    try expect(@bitReverse(u48, num48) == 0x3d591e6a2c48);
    var num56: u56 = 0x123456789abcde;
    try expect(@bitReverse(u56, num56) == 0x7b3d591e6a2c48);
    var num64: u64 = 0x123456789abcdef1;
    try expect(@bitReverse(u64, num64) == 0x8f7b3d591e6a2c48);
    var num128: u128 = 0x123456789abcdef11121314151617181;
    try expect(@bitReverse(u128, num128) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using comptime_ints, signed, positive
    try expect(@bitReverse(u8, @as(u8, 0)) == 0);
    try expect(@bitReverse(i8, @bitCast(i8, @as(u8, 0x92))) == @bitCast(i8, @as(u8, 0x49)));
    try expect(@bitReverse(i16, @bitCast(i16, @as(u16, 0x1234))) == @bitCast(i16, @as(u16, 0x2c48)));
    try expect(@bitReverse(i24, @bitCast(i24, @as(u24, 0x123456))) == @bitCast(i24, @as(u24, 0x6a2c48)));
    try expect(@bitReverse(i24, @bitCast(i24, @as(u24, 0x12345f))) == @bitCast(i24, @as(u24, 0xfa2c48)));
    try expect(@bitReverse(i24, @bitCast(i24, @as(u24, 0xf23456))) == @bitCast(i24, @as(u24, 0x6a2c4f)));
    try expect(@bitReverse(i32, @bitCast(i32, @as(u32, 0x12345678))) == @bitCast(i32, @as(u32, 0x1e6a2c48)));
    try expect(@bitReverse(i32, @bitCast(i32, @as(u32, 0xf2345678))) == @bitCast(i32, @as(u32, 0x1e6a2c4f)));
    try expect(@bitReverse(i32, @bitCast(i32, @as(u32, 0x1234567f))) == @bitCast(i32, @as(u32, 0xfe6a2c48)));
    try expect(@bitReverse(i40, @bitCast(i40, @as(u40, 0x123456789a))) == @bitCast(i40, @as(u40, 0x591e6a2c48)));
    try expect(@bitReverse(i48, @bitCast(i48, @as(u48, 0x123456789abc))) == @bitCast(i48, @as(u48, 0x3d591e6a2c48)));
    try expect(@bitReverse(i56, @bitCast(i56, @as(u56, 0x123456789abcde))) == @bitCast(i56, @as(u56, 0x7b3d591e6a2c48)));
    try expect(@bitReverse(i64, @bitCast(i64, @as(u64, 0x123456789abcdef1))) == @bitCast(i64, @as(u64, 0x8f7b3d591e6a2c48)));
    try expect(@bitReverse(i96, @bitCast(i96, @as(u96, 0x123456789abcdef111213141))) == @bitCast(i96, @as(u96, 0x828c84888f7b3d591e6a2c48)));
    try expect(@bitReverse(i128, @bitCast(i128, @as(u128, 0x123456789abcdef11121314151617181))) == @bitCast(i128, @as(u128, 0x818e868a828c84888f7b3d591e6a2c48)));

    // using signed, negative. Compare to runtime ints returned from llvm.
    var neg8: i8 = -18;
    try expect(@bitReverse(i8, @as(i8, -18)) == @bitReverse(i8, neg8));
    var neg16: i16 = -32694;
    try expect(@bitReverse(i16, @as(i16, -32694)) == @bitReverse(i16, neg16));
    var neg24: i24 = -6773785;
    try expect(@bitReverse(i24, @as(i24, -6773785)) == @bitReverse(i24, neg24));
    var neg32: i32 = -16773785;
    try expect(@bitReverse(i32, @as(i32, -16773785)) == @bitReverse(i32, neg32));
}

fn vector8() !void {
    var v = @Vector(2, u8){ 0x12, 0x23 };
    var result = @bitReverse(u8, v);
    try expect(result[0] == 0x48);
    try expect(result[1] == 0xc4);
}

test "bitReverse vectors u8" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    comptime try vector8();
    try vector8();
}

fn vector16() !void {
    var v = @Vector(2, u16){ 0x1234, 0x2345 };
    var result = @bitReverse(u16, v);
    try expect(result[0] == 0x2c48);
    try expect(result[1] == 0xa2c4);
}

test "bitReverse vectors u16" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    comptime try vector16();
    try vector16();
}

fn vector24() !void {
    var v = @Vector(2, u24){ 0x123456, 0x234567 };
    var result = @bitReverse(u24, v);
    try expect(result[0] == 0x6a2c48);
    try expect(result[1] == 0xe6a2c4);
}

test "bitReverse vectors u24" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    comptime try vector24();
    try vector24();
}

fn vector0() !void {
    var v = @Vector(2, u0){ 0, 0 };
    var result = @bitReverse(u0, v);
    try expect(result[0] == 0);
    try expect(result[1] == 0);
}

test "bitReverse vectors u0" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    comptime try vector0();
    try vector0();
}
