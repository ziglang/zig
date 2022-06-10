const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__fabsh, .{ .name = "__fabsh", .linkage = linkage });
    @export(fabsf, .{ .name = "fabsf", .linkage = linkage });
    @export(fabs, .{ .name = "fabs", .linkage = linkage });
    @export(__fabsx, .{ .name = "__fabsx", .linkage = linkage });
    @export(fabsq, .{ .name = "fabsq", .linkage = linkage });
    @export(fabsl, .{ .name = "fabsl", .linkage = linkage });

    if (!builtin.is_test) {
        if (arch.isPPC() or arch.isPPC64()) {
            @export(fabsf128, .{ .name = "fabsf128", .linkage = linkage });
        }
    }
}

pub fn __fabsh(a: f16) callconv(.C) f16 {
    return generic_fabs(a);
}

pub fn fabsf(a: f32) callconv(.C) f32 {
    return generic_fabs(a);
}

pub fn fabs(a: f64) callconv(.C) f64 {
    return generic_fabs(a);
}

pub fn __fabsx(a: f80) callconv(.C) f80 {
    return generic_fabs(a);
}

pub fn fabsq(a: f128) callconv(.C) f128 {
    return generic_fabs(a);
}

pub fn fabsf128(a: f128) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, fabsq, .{a});
}

pub fn fabsl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __fabsh(x),
        32 => return fabsf(x),
        64 => return fabs(x),
        80 => return __fabsx(x),
        128 => return fabsq(x),
        else => @compileError("unreachable"),
    }
}

inline fn generic_fabs(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const float_bits = @bitCast(TBits, x);
    const remove_sign = ~@as(TBits, 0) >> 1;
    return @bitCast(T, float_bits & remove_sign);
}
