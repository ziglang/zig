const __fixdfsi = @import("fixdfsi.zig").__fixdfsi;
const std = @import("std");
const math = std.math;
const testing = std.testing;

fn test__fixdfsi(a: f64, expected: i32) !void {
    const x = __fixdfsi(a);
    try testing.expect(x == expected);
}

test "fixdfsi" {
    try test__fixdfsi(-math.floatMax(f64), math.minInt(i32));

    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    try test__fixdfsi(-0x1.0000000000000p+127, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    try test__fixdfsi(-0x1.0000000000001p+63, -0x80000000);
    try test__fixdfsi(-0x1.0000000000000p+63, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    try test__fixdfsi(-0x1.FFFFFEp+62, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFCp+62, -0x80000000);

    try test__fixdfsi(-0x1.000000p+31, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    try test__fixdfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);

    try test__fixdfsi(-2.01, -2);
    try test__fixdfsi(-2.0, -2);
    try test__fixdfsi(-1.99, -1);
    try test__fixdfsi(-1.0, -1);
    try test__fixdfsi(-0.99, 0);
    try test__fixdfsi(-0.5, 0);
    try test__fixdfsi(-math.floatMin(f64), 0);
    try test__fixdfsi(0.0, 0);
    try test__fixdfsi(math.floatMin(f64), 0);
    try test__fixdfsi(0.5, 0);
    try test__fixdfsi(0.99, 0);
    try test__fixdfsi(1.0, 1);
    try test__fixdfsi(1.5, 1);
    try test__fixdfsi(1.99, 1);
    try test__fixdfsi(2.0, 2);
    try test__fixdfsi(2.01, 2);

    try test__fixdfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixdfsi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    try test__fixdfsi(0x1.000000p+31, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    try test__fixdfsi(math.floatMax(f64), math.maxInt(i32));
}
