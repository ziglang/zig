const __fixsfdi = @import("fixsfdi.zig").__fixsfdi;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixsfdi(a: f32, expected: i64) !void {
    const x = __fixsfdi(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u32, {x})\n", .{a, @bitCast(u32, a), x, x, expected, expected, @bitCast(u64, expected)});
    try testing.expect(x == expected);
}

test "fixsfdi" {
    //warn("\n", .{});
    try test__fixsfdi(-math.f32_max, math.minInt(i64));

    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i64));
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+1023, -0x8000000000000000);

    try test__fixsfdi(-0x1.0000000000000p+127, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+126, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFEp+126, -0x8000000000000000);

    try test__fixsfdi(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixsfdi(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+62, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFEp+62, -0x8000000000000000);

    try test__fixsfdi(-0x1.FFFFFFp+62, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixsfdi(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixsfdi(-2.01, -2);
    try test__fixsfdi(-2.0, -2);
    try test__fixsfdi(-1.99, -1);
    try test__fixsfdi(-1.0, -1);
    try test__fixsfdi(-0.99, 0);
    try test__fixsfdi(-0.5, 0);
    try test__fixsfdi(-math.f32_min, 0);
    try test__fixsfdi(0.0, 0);
    try test__fixsfdi(math.f32_min, 0);
    try test__fixsfdi(0.5, 0);
    try test__fixsfdi(0.99, 0);
    try test__fixsfdi(1.0, 1);
    try test__fixsfdi(1.5, 1);
    try test__fixsfdi(1.99, 1);
    try test__fixsfdi(2.0, 2);
    try test__fixsfdi(2.01, 2);

    try test__fixsfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixsfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixsfdi(0x1.FFFFFFp+62, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000000p+63, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000001p+63, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i64));

    try test__fixsfdi(math.f64_max, math.maxInt(i64));
}
