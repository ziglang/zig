const std = @import("std");
const fmod = @import("fmod.zig");
const testing = std.testing;

fn test_fmodq(a: f128, b: f128, exp: f128) !void {
    const res = fmod.fmodq(a, b);
    try testing.expect(exp == res);
}

fn test_fmodq_nans() !void {
    try testing.expect(std.math.isNan(fmod.fmodq(1.0, std.math.nan(f128))));
    try testing.expect(std.math.isNan(fmod.fmodq(1.0, -std.math.nan(f128))));
    try testing.expect(std.math.isNan(fmod.fmodq(std.math.nan(f128), 1.0)));
    try testing.expect(std.math.isNan(fmod.fmodq(-std.math.nan(f128), 1.0)));
}

fn test_fmodq_infs() !void {
    try testing.expect(fmod.fmodq(1.0, std.math.inf(f128)) == 1.0);
    try testing.expect(fmod.fmodq(1.0, -std.math.inf(f128)) == 1.0);
    try testing.expect(std.math.isNan(fmod.fmodq(std.math.inf(f128), 1.0)));
    try testing.expect(std.math.isNan(fmod.fmodq(-std.math.inf(f128), 1.0)));
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
    try test_fmodq(5192296858534827628530496329220095, 10.0, 5.0);
    try test_fmodq(5192296858534827628530496329220095, 922337203681230954775807, 220474884073715748246157);

    // Denormals
    const a1: f128 = 0xedcb34a235253948765432134674p-16494;
    const b1: f128 = 0x5d2e38791cfbc0737402da5a9518p-16494;
    const exp1: f128 = 0x336ec3affb2db8618e4e7d5e1c44p-16494;
    try test_fmodq(a1, b1, exp1);
    const a2: f128 = 0x0.7654_3210_fdec_ba98_7654_3210_fdecp-16382;
    const b2: f128 = 0x0.0012_fdac_bdef_1234_fdec_3222_1111p-16382;
    const exp2: f128 = 0x0.0001_aecd_9d66_4a6e_67b7_d7d0_a901p-16382;
    try test_fmodq(a2, b2, exp2);

    try test_fmodq_nans();
    try test_fmodq_infs();
}
