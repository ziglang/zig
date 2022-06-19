const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fneg, .{ .name = "__aeabi_fneg", .linkage = common.linkage });
        @export(__aeabi_dneg, .{ .name = "__aeabi_dneg", .linkage = common.linkage });
    } else {
        @export(__negsf2, .{ .name = "__negsf2", .linkage = common.linkage });
        @export(__negdf2, .{ .name = "__negdf2", .linkage = common.linkage });
    }
}

pub fn __negsf2(a: f32) callconv(.C) f32 {
    return negXf2(f32, a);
}

fn __aeabi_fneg(a: f32) callconv(.AAPCS) f32 {
    return negXf2(f32, a);
}

pub fn __negdf2(a: f64) callconv(.C) f64 {
    return negXf2(f64, a);
}

fn __aeabi_dneg(a: f64) callconv(.AAPCS) f64 {
    return negXf2(f64, a);
}

inline fn negXf2(comptime T: type, a: T) T {
    const Z = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));

    return @bitCast(T, @bitCast(Z, a) ^ signBit);
}
