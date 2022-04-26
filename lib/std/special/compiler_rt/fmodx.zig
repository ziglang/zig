const builtin = @import("builtin");
const std = @import("std");
const math = std.math;
const normalize = @import("divdf3.zig").normalize;

// fmodx - floating modulo large, returns the remainder of division for f80 types
// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn fmodx(a: f80, b: f80) callconv(.C) f80 {
    @setRuntimeSafety(builtin.is_test);

    const T = f80;
    const Z = std.meta.Int(.unsigned, @bitSizeOf(T));

    const significandBits = math.floatMantissaBits(T);
    const fractionalBits = math.floatFractionalBits(T);
    const exponentBits = math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);

    var aRep = @bitCast(Z, a);
    var bRep = @bitCast(Z, b);

    const signA = aRep & signBit;
    var expA = @intCast(i32, (@bitCast(Z, a) >> significandBits) & maxExponent);
    var expB = @intCast(i32, (@bitCast(Z, b) >> significandBits) & maxExponent);

    // There are 3 cases where the answer is undefined, check for:
    //   - fmodx(val, 0)
    //   - fmodx(val, NaN)
    //   - fmodx(inf, val)
    // The sign on checked values does not matter.
    // Doing (a * b) / (a * b) procudes undefined results
    // because the three cases always produce undefined calculations:
    //   - 0 / 0
    //   - val * NaN
    //   - inf / inf
    if (b == 0 or math.isNan(b) or expA == maxExponent) {
        return (a * b) / (a * b);
    }

    // Remove the sign from both
    aRep &= ~signBit;
    bRep &= ~signBit;
    if (aRep <= bRep) {
        if (aRep == bRep) {
            return 0 * a;
        }
        return a;
    }

    if (expA == 0) expA = normalize(f80, &aRep);
    if (expB == 0) expB = normalize(f80, &bRep);

    var highA: u64 = 0;
    var highB: u64 = 0;
    var lowA: u64 = @truncate(u64, aRep);
    var lowB: u64 = @truncate(u64, bRep);

    while (expA > expB) : (expA -= 1) {
        var high = highA -% highB;
        var low = lowA -% lowB;
        if (lowA < lowB) {
            high -%= 1;
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
        high -%= 1;
    }
    if (high >> 63 == 0) {
        if ((high | low) == 0) {
            return 0 * a;
        }
        highA = high;
        lowA = low;
    }

    while ((lowA >> fractionalBits) == 0) {
        lowA = 2 *% lowA;
        expA = expA - 1;
    }

    // Combine the exponent with the sign and significand, normalize if happened to be denormalized
    if (expA < -fractionalBits) {
        return @bitCast(T, signA);
    } else if (expA <= 0) {
        return @bitCast(T, (lowA >> @intCast(math.Log2Int(u64), 1 - expA)) | signA);
    } else {
        return @bitCast(T, lowA | (@as(Z, @intCast(u16, expA)) << significandBits) | signA);
    }
}

test {
    _ = @import("fmodx_test.zig");
}
