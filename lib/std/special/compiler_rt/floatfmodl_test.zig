const std = @import("std");
const fmodl = @import("floatfmodl.zig");
const testing = std.testing;

fn test_fmodl(a: f128, b: f128, exp: f128) !void {
    const res = fmodl.fmodl(a, b);
    try testing.expect(exp == res);
}

fn test_fmodl_nans() !void {
    try testing.expect(std.math.isNan(fmodl.fmodl(1.0, std.math.nan_f128)));
    try testing.expect(std.math.isNan(fmodl.fmodl(1.0, -std.math.nan_f128)));
    try testing.expect(std.math.isNan(fmodl.fmodl(std.math.nan_f128, 1.0)));
    try testing.expect(std.math.isNan(fmodl.fmodl(-std.math.nan_f128, 1.0)));
}

fn test_fmodl_infs() !void {
    try testing.expect(fmodl.fmodl(1.0, std.math.inf(f128)) == 1.0);
    try testing.expect(fmodl.fmodl(1.0, -std.math.inf(f128)) == 1.0);
    try testing.expect(std.math.isNan(fmodl.fmodl(std.math.inf(f128), 1.0)));
    try testing.expect(std.math.isNan(fmodl.fmodl(-std.math.inf(f128), 1.0)));
}

test "fmodl" {
    try test_fmodl(6.8, 4.0, 2.8);
    try test_fmodl(6.8, -4.0, 2.8);
    try test_fmodl(-6.8, 4.0, -2.8);
    try test_fmodl(-6.8, -4.0, -2.8);
    try test_fmodl(3.0, 2.0, 1.0);
    try test_fmodl(-5.0, 3.0, -2.0);
    try test_fmodl(3.0, 2.0, 1.0);
    try test_fmodl(1.0, 2.0, 1.0);
    try test_fmodl(0.0, 1.0, 0.0);
    try test_fmodl(-0.0, 1.0, -0.0);
    try test_fmodl(7046119.0, 5558362.0, 1487757.0);
    try test_fmodl(9010357.0, 1957236.0, 1181413.0);

    // Denormals
    const a: f128 = 0xedcb34a235253948765432134674p-16494;
    const b: f128 = 0x5d2e38791cfbc0737402da5a9518p-16494;
    const exp: f128 = 0x336ec3affb2db8618e4e7d5e1c44p-16494;
    try test_fmodl(a, b, exp);

    try test_fmodl_nans();
    try test_fmodl_infs();
}
