const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__negsf2, .{ .name = "__negsf2", .linkage = linkage });
    @export(__negdf2, .{ .name = "__negdf2", .linkage = linkage });

    if (!is_test) {
        if (arch.isARM() or arch.isThumb()) {
            @export(__aeabi_fneg, .{ .name = "__aeabi_fneg", .linkage = linkage });
            @export(__aeabi_dneg, .{ .name = "__aeabi_dneg", .linkage = linkage });
        }
    }
}

pub fn __negsf2(a: f32) callconv(.C) f32 {
    return negXf2(f32, a);
}

pub fn __negdf2(a: f64) callconv(.C) f64 {
    return negXf2(f64, a);
}

pub fn __aeabi_fneg(arg: f32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __negsf2, .{arg});
}

pub fn __aeabi_dneg(arg: f64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __negdf2, .{arg});
}

fn negXf2(comptime T: type, a: T) T {
    const Z = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));

    return @bitCast(T, @bitCast(Z, a) ^ signBit);
}
