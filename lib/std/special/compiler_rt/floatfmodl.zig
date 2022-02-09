const builtin = @import("builtin");
const std = @import("std");

// fmodl - floating modulo large, returns the remainder of division for f128 types
// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn fmodl(a: f128, b: f128) callconv(.C) f128 {
    @setRuntimeSafety(builtin.is_test);
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
    const aPtr = @ptrCast(*ReinterpretUnion, &amod);
    const bPtr = @ptrCast(*ReinterpretUnion, &bmod);

    const signA = aPtr.parts.exp_and_sign & 0x8000;
    var expA = @intCast(i32, (aPtr.parts.exp_and_sign & 0x7fff));
    var expB = bPtr.parts.exp_and_sign & 0x7fff;

    // There are 3 cases where the answer is undefined, check for:
    //   - fmodl(val, 0)
    //   - fmodl(val, NaN)
    //   - fmodl(inf, val)
    // The sign on checked values does not matter.
    // Doing (a * b) / (a * b) procudes undefined results
    // because the three cases always produce undefined calculations:
    //   - 0 / 0
    //   - val * NaN
    //   - inf / inf
    if (b == 0 or std.math.isNan(b) or expA == 0x7fff) {
        return (a * b) / (a * b);
    }

    // Remove the sign from both
    aPtr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, expA));
    bPtr.parts.exp_and_sign = @bitCast(u16, @intCast(i16, expB));
    if (amod <= bmod) {
        if (amod == bmod) {
            return 0 * a;
        }
        return a;
    }

    if (expA == 0) {
        amod *= 0x1p120;
        expA = aPtr.parts.exp_and_sign -% 120;
    }

    if (expB == 0) {
        bmod *= 0x1p120;
        expB = bPtr.parts.exp_and_sign -% 120;
    }

    // OR in extra non-stored mantissa digit
    var highA: u64 = (aPtr.u64s.high & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var highB: u64 = (bPtr.u64s.high & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var lowA: u64 = aPtr.u64s.low;
    var lowB: u64 = bPtr.u64s.low;

    while (expA > expB) : (expA -= 1) {
        var high = highA -% highB;
        var low = lowA -% lowB;
        if (lowA < lowB) {
            high = highA -% 1;
        }
        if (high >> 63 == 0) {
            if ((high | low) == 0) {
                return 0 * a;
            }
            highA = 2 *% high + (low >> 63);
            lowA = 2 *% low;
        } else {
            highA = 2 *% highA + (lowA >> 63);
            lowA = 2 *% lowA;
        }
    }

    var high = highA -% highB;
    var low = lowA -% lowB;
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
        highA = 2 *% highA + (lowA >> 63);
        lowA = 2 *% lowA;
        expA = expA - 1;
    }

    // Overwrite the current amod with the values in highA and lowA
    aPtr.u64s.high = highA;
    aPtr.u64s.low = lowA;

    // Combine the exponent with the sign, normalize if happend to be denormalized
    if (expA <= 0) {
        aPtr.parts.exp_and_sign = @truncate(u16, @bitCast(u32, (expA +% 120))) | signA;
        amod *= 0x1p-120;
    } else {
        aPtr.parts.exp_and_sign = @truncate(u16, @bitCast(u32, expA)) | signA;
    }

    return amod;
}

test {
    _ = @import("floatfmodl_test.zig");
}
