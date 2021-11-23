const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

test "uint128" {
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
    @setRuntimeSafety(true);

    // TODO implement @setRuntimeSafety in stage2
    if (@import("builtin").zig_is_stage2 and
        @import("builtin").mode != .Debug and
        @import("builtin").mode != .ReleaseSafe)
    {
        return error.SkipZigTest;
    }

    var undef: u128 = undefined;
    var undef_signed: i128 = undefined;
    try expect(undef == 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa and @bitCast(u128, undef_signed) == undef);
}

test "int128" {
    var buff: i128 = -1;
    try expect(buff < 0 and (buff + 1) == 0);
    try expect(@intCast(i8, buff) == @as(i8, -1));

    buff = minInt(i128);
    try expect(buff < 0);

    buff = -0x12341234123412341234123412341234;
    try expect(-buff == 0x12341234123412341234123412341234);
}

test "truncate int128" {
    var buff: u128 = maxInt(u128);
    try expect(@truncate(u64, buff) == maxInt(u64));
}
