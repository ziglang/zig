const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "@byteSwap integers" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;

    const ByteSwapIntTest = struct {
        fn run() !void {
            try t(u0, 0, 0);
            try t(u8, 0x12, 0x12);
            try t(u16, 0x1234, 0x3412);
            try t(u24, 0x123456, 0x563412);
            try t(i24, @bitCast(i24, @as(u24, 0xf23456)), 0x5634f2);
            try t(i24, 0x1234f6, @bitCast(i24, @as(u24, 0xf63412)));
            try t(u32, 0x12345678, 0x78563412);
            try t(i32, @bitCast(i32, @as(u32, 0xf2345678)), 0x785634f2);
            try t(i32, 0x123456f8, @bitCast(i32, @as(u32, 0xf8563412)));
            try t(u40, 0x123456789a, 0x9a78563412);
            try t(i48, 0x123456789abc, @bitCast(i48, @as(u48, 0xbc9a78563412)));
            try t(u56, 0x123456789abcde, 0xdebc9a78563412);
            try t(u64, 0x123456789abcdef1, 0xf1debc9a78563412);
            try t(u88, 0x123456789abcdef1112131, 0x312111f1debc9a78563412);
            try t(u96, 0x123456789abcdef111213141, 0x41312111f1debc9a78563412);
            try t(u128, 0x123456789abcdef11121314151617181, 0x8171615141312111f1debc9a78563412);

            try t(u0, @as(u0, 0), 0);
            try t(i8, @as(i8, -50), -50);
            try t(i16, @bitCast(i16, @as(u16, 0x1234)), @bitCast(i16, @as(u16, 0x3412)));
            try t(i24, @bitCast(i24, @as(u24, 0x123456)), @bitCast(i24, @as(u24, 0x563412)));
            try t(i32, @bitCast(i32, @as(u32, 0x12345678)), @bitCast(i32, @as(u32, 0x78563412)));
            try t(u40, @bitCast(i40, @as(u40, 0x123456789a)), @as(u40, 0x9a78563412));
            try t(i48, @bitCast(i48, @as(u48, 0x123456789abc)), @bitCast(i48, @as(u48, 0xbc9a78563412)));
            try t(i56, @bitCast(i56, @as(u56, 0x123456789abcde)), @bitCast(i56, @as(u56, 0xdebc9a78563412)));
            try t(i64, @bitCast(i64, @as(u64, 0x123456789abcdef1)), @bitCast(i64, @as(u64, 0xf1debc9a78563412)));
            try t(i88, @bitCast(i88, @as(u88, 0x123456789abcdef1112131)), @bitCast(i88, @as(u88, 0x312111f1debc9a78563412)));
            try t(i96, @bitCast(i96, @as(u96, 0x123456789abcdef111213141)), @bitCast(i96, @as(u96, 0x41312111f1debc9a78563412)));
            try t(
                i128,
                @bitCast(i128, @as(u128, 0x123456789abcdef11121314151617181)),
                @bitCast(i128, @as(u128, 0x8171615141312111f1debc9a78563412)),
            );
        }
        fn t(comptime I: type, input: I, expected_output: I) !void {
            try std.testing.expect(expected_output == @byteSwap(I, input));
        }
    };
    comptime try ByteSwapIntTest.run();
    try ByteSwapIntTest.run();
}

fn vector8() !void {
    var v = @Vector(2, u8){ 0x12, 0x13 };
    var result = @byteSwap(u8, v);
    try expect(result[0] == 0x12);
    try expect(result[1] == 0x13);
}

test "@byteSwap vectors u8" {
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
    var result = @byteSwap(u16, v);
    try expect(result[0] == 0x3412);
    try expect(result[1] == 0x4523);
}

test "@byteSwap vectors u16" {
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
    var result = @byteSwap(u24, v);
    try expect(result[0] == 0x563412);
    try expect(result[1] == 0x674523);
}

test "@byteSwap vectors u24" {
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
    var result = @byteSwap(u0, v);
    try expect(result[0] == 0);
    try expect(result[1] == 0);
}

test "@byteSwap vectors u0" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    comptime try vector0();
    try vector0();
}
