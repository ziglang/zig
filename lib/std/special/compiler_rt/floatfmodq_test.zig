const std = @import("std");
const fmodq = @import("floatfmodq.zig");
const testing = std.testing;

fn test_fmodq(a: f128, b: f128, exp: f128) !void {
    const res = fmodq.fmodq(a, b);
    try testing.expect(exp == res);
}

fn test_fmodq_nans() !void {
    try testing.expect(std.math.isNan(fmodq.fmodq(1.0, std.math.nan(f128))));
    try testing.expect(std.math.isNan(fmodq.fmodq(1.0, -std.math.nan(f128))));
    try testing.expect(std.math.isNan(fmodq.fmodq(std.math.nan(f128), 1.0)));
    try testing.expect(std.math.isNan(fmodq.fmodq(-std.math.nan(f128), 1.0)));
}

fn test_fmodq_infs() !void {
    try testing.expect(fmodq.fmodq(1.0, std.math.inf(f128)) == 1.0);
    try testing.expect(fmodq.fmodq(1.0, -std.math.inf(f128)) == 1.0);
    try testing.expect(std.math.isNan(fmodq.fmodq(std.math.inf(f128), 1.0)));
    try testing.expect(std.math.isNan(fmodq.fmodq(-std.math.inf(f128), 1.0)));
}

test "fmodq" {
    try test_fmodq(6.8, 4.0, 2.8);
    try test_fmodq(6.8, -4.0, 2.8);
    try test_fmodq(-6.8, 4.0, -2.8);
    try test_fmodq(-6.8, -4.0, -2.8);
    try test_fmodq(3.0, 2.0, 1.0);
    try test_fmodq(-5.0, 3.0, -2.0);
    try test_fmodq(3.0, 2.0, 1.0);
    try test_fmodq(1.0, 2.0, 1.0);
    try test_fmodq(0.0, 1.0, 0.0);
    try test_fmodq(-0.0, 1.0, -0.0);
    try test_fmodq(7046119.0, 5558362.0, 1487757.0);
    try test_fmodq(9010357.0, 1957236.0, 1181413.0);

    // Denormals
    const a: f128 = 0xedcb34a235253948765432134674p-16494;
    const b: f128 = 0x5d2e38791cfbc0737402da5a9518p-16494;
    const exp: f128 = 0x336ec3affb2db8618e4e7d5e1c44p-16494;
    try test_fmodq(a, b, exp);

    try test_fmodq_nans();
    try test_fmodq_infs();
}
