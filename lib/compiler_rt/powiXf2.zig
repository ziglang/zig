//! a raised to integer power of b
//! ported from https://github.com/llvm-mirror/compiler-rt/blob/release_80/lib/builtins/powisf2.c
//! Multiplication order (left-to-right or right-to-left) does not matter for
//! error propagation and this method is optimized for performance, not accuracy.

const builtin = @import("builtin");
const common = @import("common.zig");
const std = @import("std");

pub const panic = common.panic;

comptime {
    @export(&__powihf2, .{ .name = "__powihf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__powisf2, .{ .name = "__powisf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__powidf2, .{ .name = "__powidf2", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi)
        @export(&__powitf2, .{ .name = "__powikf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__powitf2, .{ .name = "__powitf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__powixf2, .{ .name = "__powixf2", .linkage = common.linkage, .visibility = common.visibility });
}

inline fn powiXf2(comptime FT: type, a: FT, b: i32) FT {
    var x_a: FT = a;
    var x_b: i32 = b;
    const is_recip: bool = b < 0;
    var r: FT = 1.0;
    while (true) {
        if (@as(u32, @bitCast(x_b)) & @as(u32, 1) != 0) {
            r *= x_a;
        }
        x_b = @divTrunc(x_b, @as(i32, 2));
        if (x_b == 0) break;
        x_a *= x_a; // Multiplication of x_a propagates the error
    }
    return if (is_recip) 1 / r else r;
}

pub fn __powihf2(a: f16, b: i32) callconv(.C) f16 {
    return powiXf2(f16, a, b);
}

pub fn __powisf2(a: f32, b: i32) callconv(.C) f32 {
    return powiXf2(f32, a, b);
}

pub fn __powidf2(a: f64, b: i32) callconv(.C) f64 {
    return powiXf2(f64, a, b);
}

pub fn __powitf2(a: f128, b: i32) callconv(.C) f128 {
    return powiXf2(f128, a, b);
}

pub fn __powixf2(a: f80, b: i32) callconv(.C) f80 {
    return powiXf2(f80, a, b);
}

test {
    _ = @import("powiXf2_test.zig");
}
