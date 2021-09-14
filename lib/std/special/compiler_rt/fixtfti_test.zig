const __fixtfti = @import("fixtfti.zig").__fixtfti;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixtfti(a: f128, expected: i128) !void {
    const x = __fixtfti(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u128, {x})\n", .{a, @bitCast(u128, a), x, x, expected, expected, @bitCast(u128, expected)});
    try testing.expect(x == expected);
}

test "fixtfti" {
    //warn("\n", .{});
    try test__fixtfti(-math.f128_max, math.minInt(i128));

    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i128));
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000000000000000000000000000);

    try test__fixtfti(-0x1.0000000000000p+127, -0x80000000000000000000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+126, -0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFEp+126, -0x7FFFFFFFFFFFF8000000000000000000);

    try test__fixtfti(-0x1.0000000000001p+63, -0x8000000000000800);
    try test__fixtfti(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    try test__fixtfti(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    try test__fixtfti(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixtfti(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixtfti(-2.01, -2);
    try test__fixtfti(-2.0, -2);
    try test__fixtfti(-1.99, -1);
    try test__fixtfti(-1.0, -1);
    try test__fixtfti(-0.99, 0);
    try test__fixtfti(-0.5, 0);
    try test__fixtfti(-math.f128_min, 0);
    try test__fixtfti(0.0, 0);
    try test__fixtfti(math.f128_min, 0);
    try test__fixtfti(0.5, 0);
    try test__fixtfti(0.99, 0);
    try test__fixtfti(1.0, 1);
    try test__fixtfti(1.5, 1);
    try test__fixtfti(1.99, 1);
    try test__fixtfti(2.0, 2);
    try test__fixtfti(2.01, 2);

    try test__fixtfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixtfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    try test__fixtfti(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixtfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixtfti(0x1.0000000000001p+63, 0x8000000000000800);

    try test__fixtfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFF8000000000000000000);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixtfti(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixtfti(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i128));

    try test__fixtfti(math.f128_max, math.maxInt(i128));
}
