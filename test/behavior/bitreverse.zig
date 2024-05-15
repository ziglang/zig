const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const minInt = std.math.minInt;

test "@bitReverse large exotic integer" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    try expect(@bitReverse(@as(u95, 0x123456789abcdef111213141)) == 0x4146424447bd9eac8f351624);
}

test "@bitReverse" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime testBitReverse();
    try testBitReverse();
}

fn testBitReverse() !void {
    // using comptime_ints, unsigned
    try expect(@bitReverse(@as(u0, 0)) == 0);
    try expect(@bitReverse(@as(u5, 0x12)) == 0x9);
    try expect(@bitReverse(@as(u8, 0x12)) == 0x48);
    try expect(@bitReverse(@as(u16, 0x1234)) == 0x2c48);
    try expect(@bitReverse(@as(u24, 0x123456)) == 0x6a2c48);
    try expect(@bitReverse(@as(u32, 0x12345678)) == 0x1e6a2c48);
    try expect(@bitReverse(@as(u40, 0x123456789a)) == 0x591e6a2c48);
    try expect(@bitReverse(@as(u48, 0x123456789abc)) == 0x3d591e6a2c48);
    try expect(@bitReverse(@as(u56, 0x123456789abcde)) == 0x7b3d591e6a2c48);
    try expect(@bitReverse(@as(u64, 0x123456789abcdef1)) == 0x8f7b3d591e6a2c48);
    try expect(@bitReverse(@as(u96, 0x123456789abcdef111213141)) == 0x828c84888f7b3d591e6a2c48);
    try expect(@bitReverse(@as(u128, 0x123456789abcdef11121314151617181)) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using runtime uints, unsigned
    var num0: u0 = 0;
    try expect(@bitReverse(num0) == 0);
    var num5: u5 = 0x12;
    try expect(@bitReverse(num5) == 0x9);
    var num8: u8 = 0x12;
    try expect(@bitReverse(num8) == 0x48);
    var num16: u16 = 0x1234;
    try expect(@bitReverse(num16) == 0x2c48);
    var num24: u24 = 0x123456;
    try expect(@bitReverse(num24) == 0x6a2c48);
    var num32: u32 = 0x12345678;
    try expect(@bitReverse(num32) == 0x1e6a2c48);
    var num40: u40 = 0x123456789a;
    try expect(@bitReverse(num40) == 0x591e6a2c48);
    var num48: u48 = 0x123456789abc;
    try expect(@bitReverse(num48) == 0x3d591e6a2c48);
    var num56: u56 = 0x123456789abcde;
    try expect(@bitReverse(num56) == 0x7b3d591e6a2c48);
    var num64: u64 = 0x123456789abcdef1;
    try expect(@bitReverse(num64) == 0x8f7b3d591e6a2c48);
    var num128: u128 = 0x123456789abcdef11121314151617181;
    try expect(@bitReverse(num128) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using comptime_ints, signed, positive
    try expect(@bitReverse(@as(u8, 0)) == 0);
    try expect(@bitReverse(@as(i8, @bitCast(@as(u8, 0x92)))) == @as(i8, @bitCast(@as(u8, 0x49))));
    try expect(@bitReverse(@as(i16, @bitCast(@as(u16, 0x1234)))) == @as(i16, @bitCast(@as(u16, 0x2c48))));
    try expect(@bitReverse(@as(i24, @bitCast(@as(u24, 0x123456)))) == @as(i24, @bitCast(@as(u24, 0x6a2c48))));
    try expect(@bitReverse(@as(i24, @bitCast(@as(u24, 0x12345f)))) == @as(i24, @bitCast(@as(u24, 0xfa2c48))));
    try expect(@bitReverse(@as(i24, @bitCast(@as(u24, 0xf23456)))) == @as(i24, @bitCast(@as(u24, 0x6a2c4f))));
    try expect(@bitReverse(@as(i32, @bitCast(@as(u32, 0x12345678)))) == @as(i32, @bitCast(@as(u32, 0x1e6a2c48))));
    try expect(@bitReverse(@as(i32, @bitCast(@as(u32, 0xf2345678)))) == @as(i32, @bitCast(@as(u32, 0x1e6a2c4f))));
    try expect(@bitReverse(@as(i32, @bitCast(@as(u32, 0x1234567f)))) == @as(i32, @bitCast(@as(u32, 0xfe6a2c48))));
    try expect(@bitReverse(@as(i40, @bitCast(@as(u40, 0x123456789a)))) == @as(i40, @bitCast(@as(u40, 0x591e6a2c48))));
    try expect(@bitReverse(@as(i48, @bitCast(@as(u48, 0x123456789abc)))) == @as(i48, @bitCast(@as(u48, 0x3d591e6a2c48))));
    try expect(@bitReverse(@as(i56, @bitCast(@as(u56, 0x123456789abcde)))) == @as(i56, @bitCast(@as(u56, 0x7b3d591e6a2c48))));
    try expect(@bitReverse(@as(i64, @bitCast(@as(u64, 0x123456789abcdef1)))) == @as(i64, @bitCast(@as(u64, 0x8f7b3d591e6a2c48))));
    try expect(@bitReverse(@as(i96, @bitCast(@as(u96, 0x123456789abcdef111213141)))) == @as(i96, @bitCast(@as(u96, 0x828c84888f7b3d591e6a2c48))));
    try expect(@bitReverse(@as(i128, @bitCast(@as(u128, 0x123456789abcdef11121314151617181)))) == @as(i128, @bitCast(@as(u128, 0x818e868a828c84888f7b3d591e6a2c48))));

    // using signed, negative. Compare to runtime ints returned from llvm.
    var neg8: i8 = -18;
    try expect(@bitReverse(@as(i8, -18)) == @bitReverse(neg8));
    var neg16: i16 = -32694;
    try expect(@bitReverse(@as(i16, -32694)) == @bitReverse(neg16));
    var neg24: i24 = -6773785;
    try expect(@bitReverse(@as(i24, -6773785)) == @bitReverse(neg24));
    var neg32: i32 = -16773785;
    try expect(@bitReverse(@as(i32, -16773785)) == @bitReverse(neg32));

    _ = .{
        &num0,
        &num5,
        &num8,
        &num16,
        &num24,
        &num32,
        &num40,
        &num48,
        &num56,
        &num64,
        &num128,
        &neg8,
        &neg16,
        &neg24,
        &neg32,
    };
}

fn vector8() !void {
    var v = @Vector(2, u8){ 0x12, 0x23 };
    _ = &v;
    const result = @bitReverse(v);
    try expect(result[0] == 0x48);
    try expect(result[1] == 0xc4);
}

test "bitReverse vectors u8" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime vector8();
    try vector8();
}

fn vector16() !void {
    var v = @Vector(2, u16){ 0x1234, 0x2345 };
    _ = &v;
    const result = @bitReverse(v);
    try expect(result[0] == 0x2c48);
    try expect(result[1] == 0xa2c4);
}

test "bitReverse vectors u16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime vector16();
    try vector16();
}

fn vector24() !void {
    var v = @Vector(2, u24){ 0x123456, 0x234567 };
    _ = &v;
    const result = @bitReverse(v);
    try expect(result[0] == 0x6a2c48);
    try expect(result[1] == 0xe6a2c4);
}

test "bitReverse vectors u24" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime vector24();
    try vector24();
}

fn vector0() !void {
    var v = @Vector(2, u0){ 0, 0 };
    _ = &v;
    const result = @bitReverse(v);
    try expect(result[0] == 0);
    try expect(result[1] == 0);
}

test "bitReverse vectors u0" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    try comptime vector0();
    try vector0();
}
