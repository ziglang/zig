const builtin = @import("builtin");
const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    // Integral -> Float Conversion

    // Conversion to f32
    @export(__floatsisf, .{ .name = "__floatsisf", .linkage = linkage });
    @export(__floatunsisf, .{ .name = "__floatunsisf", .linkage = linkage });

    @export(__floatundisf, .{ .name = "__floatundisf", .linkage = linkage });
    @export(__floatdisf, .{ .name = "__floatdisf", .linkage = linkage });

    @export(__floattisf, .{ .name = "__floattisf", .linkage = linkage });
    @export(__floatuntisf, .{ .name = "__floatuntisf", .linkage = linkage });

    // Conversion to f64
    @export(__floatsidf, .{ .name = "__floatsidf", .linkage = linkage });
    @export(__floatunsidf, .{ .name = "__floatunsidf", .linkage = linkage });

    @export(__floatdidf, .{ .name = "__floatdidf", .linkage = linkage });
    @export(__floatundidf, .{ .name = "__floatundidf", .linkage = linkage });

    @export(__floattidf, .{ .name = "__floattidf", .linkage = linkage });
    @export(__floatuntidf, .{ .name = "__floatuntidf", .linkage = linkage });

    // Conversion to f80
    @export(__floatsixf, .{ .name = "__floatsixf", .linkage = linkage });
    @export(__floatunsixf, .{ .name = "__floatunsixf", .linkage = linkage });

    @export(__floatdixf, .{ .name = "__floatdixf", .linkage = linkage });
    @export(__floatundixf, .{ .name = "__floatundixf", .linkage = linkage });

    @export(__floattixf, .{ .name = "__floattixf", .linkage = linkage });
    @export(__floatuntixf, .{ .name = "__floatuntixf", .linkage = linkage });

    // Conversion to f128
    @export(__floatsitf, .{ .name = "__floatsitf", .linkage = linkage });
    @export(__floatunsitf, .{ .name = "__floatunsitf", .linkage = linkage });

    @export(__floatditf, .{ .name = "__floatditf", .linkage = linkage });
    @export(__floatunditf, .{ .name = "__floatunditf", .linkage = linkage });

    @export(__floattitf, .{ .name = "__floattitf", .linkage = linkage });
    @export(__floatuntitf, .{ .name = "__floatuntitf", .linkage = linkage });

    if (!is_test) {
        if (arch.isARM() or arch.isThumb()) {
            @export(__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = linkage });
            @export(__aeabi_l2d, .{ .name = "__aeabi_l2d", .linkage = linkage });
            @export(__aeabi_l2f, .{ .name = "__aeabi_l2f", .linkage = linkage });
            @export(__aeabi_ui2d, .{ .name = "__aeabi_ui2d", .linkage = linkage });
            @export(__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = linkage });
            @export(__aeabi_ui2f, .{ .name = "__aeabi_ui2f", .linkage = linkage });
            @export(__aeabi_ul2f, .{ .name = "__aeabi_ul2f", .linkage = linkage });

            @export(__aeabi_i2f, .{ .name = "__aeabi_i2f", .linkage = linkage });
        }

        if (arch.isPPC() or arch.isPPC64()) {
            @export(__floatsikf, .{ .name = "__floatsikf", .linkage = linkage });
            @export(__floatdikf, .{ .name = "__floatdikf", .linkage = linkage });
            @export(__floatundikf, .{ .name = "__floatundikf", .linkage = linkage });
            @export(__floatunsikf, .{ .name = "__floatunsikf", .linkage = linkage });
            @export(__floatuntikf, .{ .name = "__floatuntikf", .linkage = linkage });
        }
    }
}

pub fn floatXiYf(comptime T: type, x: anytype) T {
    @setRuntimeSafety(is_test);

    if (x == 0) return 0;

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const Z = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(x)));
    const uT = std.meta.Int(.unsigned, @bitSizeOf(T));
    const inf = math.inf(T);
    const float_bits = @bitSizeOf(T);
    const int_bits = @bitSizeOf(@TypeOf(x));
    const exp_bits = math.floatExponentBits(T);
    const fractional_bits = math.floatFractionalBits(T);
    const exp_bias = math.maxInt(std.meta.Int(.unsigned, exp_bits - 1));
    const implicit_bit = if (T != f80) @as(uT, 1) << fractional_bits else 0;
    const max_exp = exp_bias;

    // Sign
    var abs_val = math.absCast(x);
    const sign_bit = if (x < 0) @as(uT, 1) << (float_bits - 1) else 0;
    var result: uT = sign_bit;

    // Compute significand
    var exp = int_bits - @clz(Z, abs_val) - 1;
    if (int_bits <= fractional_bits or exp <= fractional_bits) {
        const shift_amt = fractional_bits - @intCast(math.Log2Int(uT), exp);

        // Shift up result to line up with the significand - no rounding required
        result = (@intCast(uT, abs_val) << shift_amt);
        result ^= implicit_bit; // Remove implicit integer bit
    } else {
        var shift_amt = @intCast(math.Log2Int(Z), exp - fractional_bits);
        const exact_tie: bool = @ctz(Z, abs_val) == shift_amt - 1;

        // Shift down result and remove implicit integer bit
        result = @intCast(uT, (abs_val >> (shift_amt - 1))) ^ (implicit_bit << 1);

        // Round result, including round-to-even for exact ties
        result = ((result + 1) >> 1) & ~@as(uT, @boolToInt(exact_tie));
    }

    // Compute exponent
    if ((int_bits > max_exp) and (exp > max_exp)) // If exponent too large, overflow to infinity
        return @bitCast(T, sign_bit | @bitCast(uT, inf));

    result += (@as(uT, exp) + exp_bias) << math.floatMantissaBits(T);

    // If the result included a carry, we need to restore the explicit integer bit
    if (T == f80) result |= 1 << fractional_bits;

    return @bitCast(T, sign_bit | result);
}

// Conversion to f16
pub fn __floatsihf(a: i32) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

pub fn __floatunsihf(a: u32) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

pub fn __floatdihf(a: i64) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

pub fn __floatundihf(a: u64) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

pub fn __floattihf(a: i128) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

pub fn __floatuntihf(a: u128) callconv(.C) f16 {
    return floatXiYf(f16, a);
}

// Conversion to f32
pub fn __floatsisf(a: i32) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

pub fn __floatunsisf(a: u32) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

pub fn __floatdisf(a: i64) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

pub fn __floatundisf(a: u64) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

pub fn __floattisf(a: i128) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

pub fn __floatuntisf(a: u128) callconv(.C) f32 {
    return floatXiYf(f32, a);
}

// Conversion to f64
pub fn __floatsidf(a: i32) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

pub fn __floatunsidf(a: u32) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

pub fn __floatdidf(a: i64) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

pub fn __floatundidf(a: u64) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

pub fn __floattidf(a: i128) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

pub fn __floatuntidf(a: u128) callconv(.C) f64 {
    return floatXiYf(f64, a);
}

// Conversion to f80
pub fn __floatsixf(a: i32) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

pub fn __floatunsixf(a: u32) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

pub fn __floatdixf(a: i64) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

pub fn __floatundixf(a: u64) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

pub fn __floattixf(a: i128) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

pub fn __floatuntixf(a: u128) callconv(.C) f80 {
    return floatXiYf(f80, a);
}

// Conversion to f128
pub fn __floatsitf(a: i32) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatsikf(a: i32) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __floatsitf, .{a});
}

pub fn __floatunsitf(a: u32) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatunsikf(a: u32) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __floatunsitf, .{a});
}

pub fn __floatditf(a: i64) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatdikf(a: i64) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __floatditf, .{a});
}

pub fn __floatunditf(a: u64) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatundikf(a: u64) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __floatunditf, .{a});
}

pub fn __floattitf(a: i128) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return floatXiYf(f128, a);
}

pub fn __floatuntikf(a: u128) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __floatuntitf, .{a});
}

// Conversion to f32
pub fn __aeabi_ui2f(arg: u32) callconv(.AAPCS) f32 {
    return floatXiYf(f32, arg);
}

pub fn __aeabi_i2f(arg: i32) callconv(.AAPCS) f32 {
    return floatXiYf(f32, arg);
}

pub fn __aeabi_ul2f(arg: u64) callconv(.AAPCS) f32 {
    return floatXiYf(f32, arg);
}

pub fn __aeabi_l2f(arg: i64) callconv(.AAPCS) f32 {
    return floatXiYf(f32, arg);
}

// Conversion to f64
pub fn __aeabi_ui2d(arg: u32) callconv(.AAPCS) f64 {
    return floatXiYf(f64, arg);
}

pub fn __aeabi_i2d(arg: i32) callconv(.AAPCS) f64 {
    return floatXiYf(f64, arg);
}

pub fn __aeabi_ul2d(arg: u64) callconv(.AAPCS) f64 {
    return floatXiYf(f64, arg);
}

pub fn __aeabi_l2d(arg: i64) callconv(.AAPCS) f64 {
    return floatXiYf(f64, arg);
}

test {
    _ = @import("floatXiYf_test.zig");
}
