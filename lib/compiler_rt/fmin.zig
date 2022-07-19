const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const arch = builtin.cpu.arch;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__fminh, .{ .name = "__fminh", .linkage = linkage });
    @export(fminf, .{ .name = "fminf", .linkage = linkage });
    @export(fmin, .{ .name = "fmin", .linkage = linkage });
    @export(__fminx, .{ .name = "__fminx", .linkage = linkage });
    @export(fminq, .{ .name = "fminq", .linkage = linkage });
    @export(fminl, .{ .name = "fminl", .linkage = linkage });

    if (!builtin.is_test) {
        if (arch.isPPC() or arch.isPPC64()) {
            @export(fminf128, .{ .name = "fminf128", .linkage = linkage });
        }
    }
}

pub fn __fminh(x: f16, y: f16) callconv(.C) f16 {
    return generic_fmin(f16, x, y);
}

pub fn fminf(x: f32, y: f32) callconv(.C) f32 {
    return generic_fmin(f32, x, y);
}

pub fn fmin(x: f64, y: f64) callconv(.C) f64 {
    return generic_fmin(f64, x, y);
}

pub fn __fminx(x: f80, y: f80) callconv(.C) f80 {
    return generic_fmin(f80, x, y);
}

pub fn fminq(x: f128, y: f128) callconv(.C) f128 {
    return generic_fmin(f128, x, y);
}

pub fn fminf128(x: f128, y: f128) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, fminq, .{ x, y });
}

pub fn fminl(x: c_longdouble, y: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __fminh(x, y),
        32 => return fminf(x, y),
        64 => return fmin(x, y),
        80 => return __fminx(x, y),
        128 => return fminq(x, y),
        else => @compileError("unreachable"),
    }
}

inline fn generic_fmin(comptime T: type, x: T, y: T) T {
    if (math.isNan(x))
        return y;
    if (math.isNan(y))
        return x;
    return if (x < y) x else y;
}

test "generic_fmin" {
    inline for ([_]type{ f32, f64, c_longdouble, f80, f128 }) |T| {
        const nan_val = math.nan(T);

        try std.testing.expect(math.isNan(generic_fmin(T, nan_val, nan_val)));
        try std.testing.expectEqual(@as(T, 1.0), generic_fmin(T, nan_val, 1.0));
        try std.testing.expectEqual(@as(T, 1.0), generic_fmin(T, 1.0, nan_val));

        try std.testing.expectEqual(@as(T, 1.0), generic_fmin(T, 1.0, 10.0));
        try std.testing.expectEqual(@as(T, -1.0), generic_fmin(T, 1.0, -1.0));
    }
}
