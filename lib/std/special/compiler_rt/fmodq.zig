const builtin = @import("builtin");
const std = @import("std");

// fmodq - floating modulo large, returns the remainder of division for f128 types
// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn fmodq(a: f128, b: f128) callconv(.C) f128 {
    @setRuntimeSafety(builtin.is_test);
    var amod = a;
    var bmod = b;
    const aPtr_u64 = @ptrCast([*]u64, &amod);
    const bPtr_u64 = @ptrCast([*]u64, &bmod);
    const aPtr_u16 = @ptrCast([*]u16, &amod);
    const bPtr_u16 = @ptrCast([*]u16, &bmod);

    const exp_and_sign_index = comptime switch (builtin.target.cpu.arch.endian()) {
        .Little => 7,
        .Big => 0,
    };
    const low_index = comptime switch (builtin.target.cpu.arch.endian()) {
        .Little => 0,
        .Big => 1,
    };
    const high_index = comptime switch (builtin.target.cpu.arch.endian()) {
        .Little => 1,
        .Big => 0,
    };

    const signA = aPtr_u16[exp_and_sign_index] & 0x8000;
    var expA = @intCast(i32, (aPtr_u16[exp_and_sign_index] & 0x7fff));
    var expB = @intCast(i32, (bPtr_u16[exp_and_sign_index] & 0x7fff));

    // There are 3 cases where the answer is undefined, check for:
    //   - fmodq(val, 0)
    //   - fmodq(val, NaN)
    //   - fmodq(inf, val)
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
    aPtr_u16[exp_and_sign_index] = @bitCast(u16, @intCast(i16, expA));
    bPtr_u16[exp_and_sign_index] = @bitCast(u16, @intCast(i16, expB));
    if (amod <= bmod) {
        if (amod == bmod) {
            return 0 * a;
        }
        return a;
    }

    if (expA == 0) {
        amod *= 0x1p120;
        expA = @as(i32, aPtr_u16[exp_and_sign_index]) - 120;
    }

    if (expB == 0) {
        bmod *= 0x1p120;
        expB = @as(i32, bPtr_u16[exp_and_sign_index]) - 120;
    }

    // OR in extra non-stored mantissa digit
    var highA: u64 = (aPtr_u64[high_index] & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var highB: u64 = (bPtr_u64[high_index] & (std.math.maxInt(u64) >> 16)) | 1 << 48;
    var lowA: u64 = aPtr_u64[low_index];
    var lowB: u64 = bPtr_u64[low_index];

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
    aPtr_u64[high_index] = highA;
    aPtr_u64[low_index] = lowA;

    // Combine the exponent with the sign, normalize if happend to be denormalized
    if (expA <= 0) {
        aPtr_u16[exp_and_sign_index] = @truncate(u16, @bitCast(u32, (expA +% 120))) | signA;
        amod *= 0x1p-120;
    } else {
        aPtr_u16[exp_and_sign_index] = @truncate(u16, @bitCast(u32, expA)) | signA;
    }

    return amod;
}

test {
    _ = @import("fmodq_test.zig");
}
