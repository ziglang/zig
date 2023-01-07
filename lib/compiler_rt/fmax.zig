const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__fmaxh, .{ .name = "__fmaxh", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmaxf, .{ .name = "fmaxf", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmax, .{ .name = "fmax", .linkage = common.linkage, .visibility = common.visibility });
    @export(__fmaxx, .{ .name = "__fmaxx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(fmaxq, .{ .name = "fmaxf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(fmaxq, .{ .name = "fmaxq", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmaxl, .{ .name = "fmaxl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fmaxh(x: f16, y: f16) callconv(.C) f16 {
    return generic_fmax(f16, x, y);
}

pub fn fmaxf(x: f32, y: f32) callconv(.C) f32 {
    return generic_fmax(f32, x, y);
}

pub fn fmax(x: f64, y: f64) callconv(.C) f64 {
    return generic_fmax(f64, x, y);
}

pub fn __fmaxx(x: f80, y: f80) callconv(.C) f80 {
    return generic_fmax(f80, x, y);
}

pub fn fmaxq(x: f128, y: f128) callconv(.C) f128 {
    return generic_fmax(f128, x, y);
}

pub fn fmaxl(x: c_longdouble, y: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __fmaxh(x, y),
        32 => return fmaxf(x, y),
        64 => return fmax(x, y),
        80 => return __fmaxx(x, y),
        128 => return fmaxq(x, y),
        else => @compileError("unreachable"),
    }
}

inline fn generic_fmax(comptime T: type, x: T, y: T) T {
    if (math.isNan(x))
        return y;
    if (math.isNan(y))
        return x;
    return if (x < y) y else x;
}

test "generic_fmax" {
    inline for ([_]type{ f32, f64, c_longdouble, f80, f128 }) |T| {
        const nan_val = math.nan(T);

        try std.testing.expect(math.isNan(generic_fmax(T, nan_val, nan_val)));
        try std.testing.expectEqual(@as(T, 1.0), generic_fmax(T, nan_val, 1.0));
        try std.testing.expectEqual(@as(T, 1.0), generic_fmax(T, 1.0, nan_val));

        try std.testing.expectEqual(@as(T, 10.0), generic_fmax(T, 1.0, 10.0));
        try std.testing.expectEqual(@as(T, 1.0), generic_fmax(T, 1.0, -1.0));
    }
}
