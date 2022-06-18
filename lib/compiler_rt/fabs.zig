const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__fabsh, .{ .name = "__fabsh", .linkage = common.linkage });
    @export(fabsf, .{ .name = "fabsf", .linkage = common.linkage });
    @export(fabs, .{ .name = "fabs", .linkage = common.linkage });
    @export(__fabsx, .{ .name = "__fabsx", .linkage = common.linkage });
    const fabsq_sym_name = if (common.want_ppc_abi) "fabsf128" else "fabsq";
    @export(fabsq, .{ .name = fabsq_sym_name, .linkage = common.linkage });
    @export(fabsl, .{ .name = "fabsl", .linkage = common.linkage });
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
