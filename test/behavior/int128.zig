const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const builtin = @import("builtin");

test "uint128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    @setRuntimeSafety(true);

    // TODO implement @setRuntimeSafety in stage2
    if (builtin.zig_backend != .stage1 and builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
        return error.SkipZigTest;
    }

    var undef: u128 = undefined;
    var undef_signed: i128 = undefined;
    try expect(undef == 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa and @bitCast(u128, undef_signed) == undef);
}

test "int128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var buff: i128 = -1;
    try expect(buff < 0 and (buff + 1) == 0);
    try expect(@intCast(i8, buff) == @as(i8, -1));

    buff = minInt(i128);
    try expect(buff < 0);

    buff = -0x12341234123412341234123412341234;
    try expect(-buff == 0x12341234123412341234123412341234);
}

test "truncate int128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var buff: u128 = maxInt(u128);
    try expect(@truncate(u64, buff) == maxInt(u64));
}
