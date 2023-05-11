const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const builtin = @import("builtin");

test "uint128" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var buff: u128 = maxInt(u128);
    try expect(buff == maxInt(u128));

    const magic_const = 0x12341234123412341234123412341234;
    buff = magic_const;

    try expect(buff == magic_const);
    try expect(magic_const == 0x12341234123412341234123412341234);

    buff = 0;
    try expect(buff == @as(u128, 0));
}

test "undefined 128 bit int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    @setRuntimeSafety(true);

    // TODO implement @setRuntimeSafety
    if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
        return error.SkipZigTest;
    }

    var undef: u128 = undefined;
    var undef_signed: i128 = undefined;
    try expect(undef == 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa and @bitCast(u128, undef_signed) == undef);
}

test "int128" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var buff: i128 = -1;
    try expect(buff < 0 and (buff + 1) == 0);
    try expect(@intCast(i8, buff) == @as(i8, -1));

    buff = minInt(i128);
    try expect(buff < 0);

    buff = -0x12341234123412341234123412341234;
    try expect(-buff == 0x12341234123412341234123412341234);

    const a: i128 = -170141183460469231731687303715884105728;
    const b: i128 = -0x8000_0000_0000_0000_0000_0000_0000_0000;
    try expect(@divFloor(b, 1_000_000) == -170141183460469231731687303715885);
    try expect(a == b);
}

test "truncate int128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    {
        var buff: u128 = maxInt(u128);
        try expect(@truncate(u64, buff) == maxInt(u64));
        try expect(@truncate(u90, buff) == maxInt(u90));
        try expect(@truncate(u128, buff) == maxInt(u128));
    }

    {
        var buff: i128 = maxInt(i128);
        try expect(@truncate(i64, buff) == -1);
        try expect(@truncate(i90, buff) == -1);
        try expect(@truncate(i128, buff) == maxInt(i128));
    }
}

test "shift int128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const types = .{ u128, i128 };
    inline for (types) |t| {
        try testShlTrunc(t, 0x8, 123);
        comptime try testShlTrunc(t, 0x8, 123);

        try testShlTrunc(t, 0x40000000_00000000, 64);
        comptime try testShlTrunc(t, 0x40000000_00000000, 64);

        try testShlTrunc(t, 0x01000000_00000000_00000000, 38);
        comptime try testShlTrunc(t, 0x01000000_00000000_00000000, 38);

        try testShlTrunc(t, 0x00000008_00000000_00000000_00000000, 27);
        comptime try testShlTrunc(t, 0x00000008_00000000_00000000_00000000, 27);
    }
}

fn testShlTrunc(comptime Type: type, x: Type, rhs: u7) !void {
    const shifted = x << rhs;
    try expect(shifted == @as(Type, 0x40000000_00000000_00000000_00000000));
}
