const __fixtfsi = @import("fixtfsi.zig").__fixtfsi;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixtfsi(a: f128, expected: i32) !void {
    const x = __fixtfsi(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u32, {x})\n", .{a, @bitCast(u128, a), x, x, expected, expected, @bitCast(u32, expected)});
    try testing.expect(x == expected);
}

test "fixtfsi" {
    //warn("\n", .{});
    try test__fixtfsi(-math.f128_max, math.minInt(i32));

    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    try test__fixtfsi(-0x1.0000000000000p+127, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    try test__fixtfsi(-0x1.0000000000001p+63, -0x80000000);
    try test__fixtfsi(-0x1.0000000000000p+63, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    try test__fixtfsi(-0x1.FFFFFEp+62, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFCp+62, -0x80000000);

    try test__fixtfsi(-0x1.000000p+31, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    try test__fixtfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixtfsi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixtfsi(-2.01, -2);
    try test__fixtfsi(-2.0, -2);
    try test__fixtfsi(-1.99, -1);
    try test__fixtfsi(-1.0, -1);
    try test__fixtfsi(-0.99, 0);
    try test__fixtfsi(-0.5, 0);
    try test__fixtfsi(-math.f32_min, 0);
    try test__fixtfsi(0.0, 0);
    try test__fixtfsi(math.f32_min, 0);
    try test__fixtfsi(0.5, 0);
    try test__fixtfsi(0.99, 0);
    try test__fixtfsi(1.0, 1);
    try test__fixtfsi(1.5, 1);
    try test__fixtfsi(1.99, 1);
    try test__fixtfsi(2.0, 2);
    try test__fixtfsi(2.01, 2);

    try test__fixtfsi(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixtfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixtfsi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    try test__fixtfsi(0x1.000000p+31, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    try test__fixtfsi(math.f128_max, math.maxInt(i32));
}
