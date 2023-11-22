const std = @import("std");
const builtin = @import("builtin");
const fmod = @import("fmod.zig");
const testing = std.testing;

fn test_fmodx(a: f80, b: f80, exp: f80) !void {
    const res = fmod.__fmodx(a, b);
    try testing.expect(exp == res);
}

fn test_fmodx_nans() !void {
    try testing.expect(std.math.isNan(fmod.__fmodx(1.0, std.math.nan(f80))));
    try testing.expect(std.math.isNan(fmod.__fmodx(1.0, -std.math.nan(f80))));
    try testing.expect(std.math.isNan(fmod.__fmodx(std.math.nan(f80), 1.0)));
    try testing.expect(std.math.isNan(fmod.__fmodx(-std.math.nan(f80), 1.0)));
}

fn test_fmodx_infs() !void {
    try testing.expect(fmod.__fmodx(1.0, std.math.inf(f80)) == 1.0);
    try testing.expect(fmod.__fmodx(1.0, -std.math.inf(f80)) == 1.0);
    try testing.expect(std.math.isNan(fmod.__fmodx(std.math.inf(f80), 1.0)));
    try testing.expect(std.math.isNan(fmod.__fmodx(-std.math.inf(f80), 1.0)));
}

test "fmodx" {
    try test_fmodx(6.4, 4.0, 2.4);
    try test_fmodx(6.4, -4.0, 2.4);
    try test_fmodx(-6.4, 4.0, -2.4);
    try test_fmodx(-6.4, -4.0, -2.4);
    try test_fmodx(3.0, 2.0, 1.0);
    try test_fmodx(-5.0, 3.0, -2.0);
    try test_fmodx(3.0, 2.0, 1.0);
    try test_fmodx(1.0, 2.0, 1.0);
    try test_fmodx(0.0, 1.0, 0.0);
    try test_fmodx(-0.0, 1.0, -0.0);
    try test_fmodx(7046119.0, 5558362.0, 1487757.0);
    try test_fmodx(9010357.0, 1957236.0, 1181413.0);
    try test_fmodx(9223372036854775807, 10.0, 7.0);

    // Denormals
    const a1: f80 = 0x0.76e5_9a51_1a92_9ca4p-16381;
    const b1: f80 = 0x0.2e97_1c3c_8e7d_e03ap-16381;
    const exp1: f80 = 0x0.19b7_61d7_fd96_dc30p-16381;
    try test_fmodx(a1, b1, exp1);
    const a2: f80 = 0x0.76e5_9a51_1a92_9ca4p-16381;
    const b2: f80 = 0x0.0e97_1c3c_8e7d_e03ap-16381;
    const exp2: f80 = 0x0.022c_b86c_a6a3_9ad4p-16381;
    try test_fmodx(a2, b2, exp2);

    try test_fmodx_nans();
    try test_fmodx_infs();
}
