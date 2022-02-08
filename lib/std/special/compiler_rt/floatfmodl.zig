const builtin = @import("builtin");
const std = @import("std");

// fmodl - floating modulo large, returns the remainder of division for f128 types
// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn fmodl(a: f128, b: f128) callconv(.C) f128 {
    @setRuntimeSafety(false);
    const ReinterpretUnion = packed union {
        u64s: switch (builtin.cpu.arch.endian()) {
            .Little => extern struct {
                low: u64,
                high: u64,
            },
            .Big => extern struct {
                high: u64,
                low: u64,
            },
        },

        parts: switch (builtin.cpu.arch.endian()) {
            .Little => extern struct {
                mantissa_low: u64,
                mantissa_mid: u32,
                mantissa_high: u16,
                exp_and_sign: u16,
            },
            .Big => extern struct {
                exp_and_sign: u16,
                mantissa_high: u16,
                mantissa_mid: u32,
                mantissa_low: u64,
            },
        },
    };

    var amod = a;
    var bmod = b;
    const a_ptr = @ptrCast(*ReinterpretUnion, &amod);
    const b_ptr = @ptrCast(*ReinterpretUnion, &bmod);

    const sign_a = a_ptr.parts.exp_and_sign & 0x8000;
    var exp_a = @intCast(i32, (a_ptr.parts.exp_and_sign & 0x7fff));
    var exp_b = b_ptr.parts.exp_and_sign & 0x7fff;

    if (b == 0 or std.math.isNan(b) or exp_a == 0x7fff) {
        return (a * b) / (a * b);
    }

    // Remove the sign from both
    a_ptr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, exp_a));
    b_ptr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, exp_b));
    if (amod <= bmod) {
        if (amod == bmod) {
            return 0 * a;
        }
        return a;
    }

    if (exp_a == 0) {
        amod *= 0x1p120;
        exp_a = a_ptr.parts.exp_and_sign - 120;
    }

    if (exp_b == 0) {
        bmod *= 0x1p120;
        exp_b = b_ptr.parts.exp_and_sign - 120;
    }

    // OR in extra non-stored mantissa digit
    var highA: u64 = (a_ptr.u64s.high & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var highB: u64 = (b_ptr.u64s.high & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var lowA: u64 = a_ptr.u64s.low;
    var lowB: u64 = b_ptr.u64s.low;

    while (exp_a > exp_b) : (exp_a -= 1) {
        var high = highA - highB;
        var low = lowA - lowB;
        if (lowA < lowB) {
            high -= 1;
        }
        if (high >> 63 == 0) {
            if ((high | low) == 0) {
                return 0 * a;
            }
            highA = 2 * high + (low >> 63);
            lowA = 2 * low;
        } else {
            highA = 2 * highA + (lowA >> 63);
            lowA = 2 * lowA;
        }
    }

    var high: u64 = highA - highB;
    var low: u64 = lowA - lowB;
    if (lowA < lowB) {
        high -= 1;
    }
    if (high >> 63 == 0) {
        if ((high | low) == 0) {
            return 0 * a;
        }
        highA = high;
        lowA = low;
    }

    while (highA >> 48 == 0) {
        highA = 2 * highA + (lowA >> 63);
        lowA = 2 * lowA;
        exp_a -= 1;
    }

    // Overwrite the current amod with the values in highA and lowA
    a_ptr.u64s.high = highA;
    a_ptr.u64s.low = lowA;

    // Combine the exponent with the sign, normalize if happend to be denormalized
    if (exp_a <= 0) {
        a_ptr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, @intCast(u32, exp_a + 120) | sign_a));
        amod *= 0x1p-120;
    } else {
        a_ptr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, @intCast(u32, exp_a) | sign_a));
    }

    return amod;
}

test {
    _ = @import("floatfmodl_test.zig");
}
