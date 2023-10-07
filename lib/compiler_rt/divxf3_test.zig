const std = @import("std");
const math = std.math;
const testing = std.testing;

const __divxf3 = @import("divxf3.zig").__divxf3;

fn compareResult(result: f80, expected: u80) bool {
    const rep: u80 = @bitCast(result);

    if (rep == expected) return true;
    // test other possible NaN representations (signal NaN)
    if (math.isNan(result) and math.isNan(@as(f80, @bitCast(expected)))) return true;

    return false;
}

fn expect__divxf3_result(a: f80, b: f80, expected: u80) !void {
    const x = __divxf3(a, b);
    const ret = compareResult(x, expected);
    try testing.expect(ret == true);
}

fn test__divxf3(a: f80, b: f80) !void {
    const integerBit = 1 << math.floatFractionalBits(f80);
    const x = __divxf3(a, b);

    // Next float (assuming normal, non-zero result)
    const x_plus_eps: f80 = @bitCast((@as(u80, @bitCast(x)) + 1) | integerBit);
    // Prev float (assuming normal, non-zero result)
    const x_minus_eps: f80 = @bitCast((@as(u80, @bitCast(x)) - 1) | integerBit);

    // Make sure result is more accurate than the adjacent floats
    const err_x = @abs(@mulAdd(f80, x, b, -a));
    const err_x_plus_eps = @abs(@mulAdd(f80, x_plus_eps, b, -a));
    const err_x_minus_eps = @abs(@mulAdd(f80, x_minus_eps, b, -a));

    try testing.expect(err_x_minus_eps > err_x);
    try testing.expect(err_x_plus_eps > err_x);
}

test "divxf3" {
    // NaN / any = NaN
    try expect__divxf3_result(math.nan(f80), 0x1.23456789abcdefp+5, 0x7fffC000000000000000);
    // inf / any(except inf and nan) = inf
    try expect__divxf3_result(math.inf(f80), 0x1.23456789abcdefp+5, 0x7fff8000000000000000);
    // inf / inf = nan
    try expect__divxf3_result(math.inf(f80), math.inf(f80), 0x7fffC000000000000000);
    // inf / nan = nan
    try expect__divxf3_result(math.inf(f80), math.nan(f80), 0x7fffC000000000000000);

    try test__divxf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.eedcbaba3a94546558237654321fp-1);
    try test__divxf3(0x1.a2b34c56d745382f9abf2c3dfeffp-50, 0x1.ed2c3ba15935332532287654321fp-9);
    try test__divxf3(0x1.2345f6aaaa786555f42432abcdefp+456, 0x1.edacbba9874f765463544dd3621fp+6400);
    try test__divxf3(0x1.2d3456f789ba6322bc665544edefp-234, 0x1.eddcdba39f3c8b7a36564354321fp-4455);
    try test__divxf3(0x1.2345f6b77b7a8953365433abcdefp+234, 0x1.edcba987d6bb3aa467754354321fp-4055);
    try test__divxf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.a2b34c56d745382f9abf2c3dfeffp-50);
    try test__divxf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.1234567890abcdef987654321123p0);
    try test__divxf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.12394205810257120adae8929f23p+16);
    try test__divxf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.febdcefa1231245f9abf2c3dfeffp-50);

    // Result rounds down to zero
    try expect__divxf3_result(6.72420628622418701252535563464350521E-4932, 2.0, 0x0);
}
