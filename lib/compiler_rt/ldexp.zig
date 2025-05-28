const std = @import("std");
const math = std.math;
const common = @import("common.zig");
const exp2 = @import("exp2.zig");

pub const panic = common.panic;

comptime {
    @export(&ldexpf, .{ .name = "ldexpf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexp, .{ .name = "ldexp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexpl, .{ .name = "ldexpl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn ldexpf(x: f32, exp: i32) callconv(.c) f32 {
    if (exp == 0) return x;
    if (exp > 0) {
        if (exp < 32) {
            const factor = (@as(u32, 1) << @intCast(exp));
            return x * @as(f32, @floatFromInt(factor));
        } else return x * exp2.exp2f(@floatFromInt(exp));
    }
    if (exp > -32) {
        const divisor = (@as(u32, 1) << @intCast(-exp));
        return x / @as(f32, @floatFromInt(divisor));
    } else return x * exp2.exp2f(@floatFromInt(exp));
}
test "ldexpf" {
    const epsilon = 0.000001;
    try std.testing.expectApproxEqAbs(2.0, ldexpf(2, 0), epsilon);
    try std.testing.expectApproxEqAbs(2147483600, ldexpf(1, 31), epsilon);
    try std.testing.expectApproxEqAbs(math.maxInt(u32), ldexpf(2, 31), epsilon);
    try std.testing.expectApproxEqAbs(0.437500, ldexpf(7, -4), epsilon);
    try std.testing.expectApproxEqAbs(1.79769e+388, ldexpf(1, 1024), epsilon);
    try std.testing.expectApproxEqAbs(0, ldexpf(0, 10), epsilon);
    try std.testing.expect(math.isNegativeInf(ldexpf(-math.inf(f32), -1)));
    try std.testing.expect(math.isPositiveInf(ldexpf(1.0, 1024)));
}

pub fn ldexp(x: f64, exp: i32) callconv(.c) f64 {
    if (exp == 0) return x;
    if (exp > 0) {
        if (exp < 64) {
            const factor = (@as(u64, 1) << @intCast(exp));
            return x * @as(f64, @floatFromInt(factor));
        } else return x * exp2.exp2(@floatFromInt(exp));
    }
    if (exp > -64) {
        const divisor = (@as(u64, 1) << @intCast(-exp));
        return x / @as(f64, @floatFromInt(divisor));
    } else return x * exp2.exp2(@floatFromInt(exp));
}
test "ldexp" {
    const epsilon = 0.00000000001;
    try std.testing.expectApproxEqAbs(2.0, ldexp(2, 0), epsilon);
    try std.testing.expectApproxEqAbs(9223372036854775807, ldexp(1, 63), epsilon);
    try std.testing.expectApproxEqAbs(math.maxInt(u64), ldexp(2, 63), epsilon);
    try std.testing.expectApproxEqAbs(math.maxInt(u64), ldexp(1, 64), epsilon);
    try std.testing.expectApproxEqAbs(0.437500, ldexp(7, -4), epsilon);
    try std.testing.expectApproxEqAbs(1.79769e+388, ldexp(1, 1024), epsilon);
    try std.testing.expectApproxEqAbs(0, ldexp(0, 10), epsilon);
    try std.testing.expect(math.isNegativeInf(ldexp(-math.inf(f64), -1)));
    try std.testing.expect(math.isPositiveInf(ldexp(1.0, 1024)));
}

pub fn ldexpl(x: f128, exp: i32) callconv(.c) f128 {
    if (exp == 0) return x;
    if (exp > 0) {
        if (exp < 128) {
            const factor = (@as(u128, 1) << @intCast(exp));
            return x * @as(f128, @floatFromInt(factor));
        } else return x * exp2.exp2l(@floatFromInt(exp));
    }
    if (exp > -128) {
        const divisor = (@as(u128, 1) << @intCast(-exp));
        return x / @as(f128, @floatFromInt(divisor));
    } else return x * exp2.exp2l(@floatFromInt(exp));
}

test "ldexpl" {
    const epsilon = 0.000000000000000000001;
    try std.testing.expectApproxEqAbs(2.0, ldexpl(2, 0), epsilon);
    try std.testing.expectApproxEqAbs(1.701411834604692317316873037158841e38, ldexpl(1, 127), epsilon);
    try std.testing.expectApproxEqAbs(math.maxInt(u128), ldexpl(2, 127), epsilon);
    try std.testing.expectApproxEqAbs(math.maxInt(u128), ldexpl(1, 128), epsilon);
    try std.testing.expectApproxEqAbs(0.437500, ldexpl(7, -4), epsilon);
    try std.testing.expectApproxEqAbs(0, ldexpl(0, 10), epsilon);
    try std.testing.expect(math.isNegativeInf(ldexpl(-math.inf(f128), -1)));
    try std.testing.expect(math.isPositiveInf(ldexpl(1, 1024)));
}

