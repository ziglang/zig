const builtin = @import("builtin");
const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const arch = builtin.cpu.arch;
const common = @import("common.zig");
const normalize = common.normalize;

pub const panic = common.panic;

comptime {
    @export(__fmodh, .{ .name = "__fmodh", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmodf, .{ .name = "fmodf", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmod, .{ .name = "fmod", .linkage = common.linkage, .visibility = common.visibility });
    @export(__fmodx, .{ .name = "__fmodx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(fmodq, .{ .name = "fmodf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(fmodq, .{ .name = "fmodq", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmodl, .{ .name = "fmodl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fmodh(x: f16, y: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(fmodf(x, y));
}

pub fn fmodf(x: f32, y: f32) callconv(.C) f32 {
    return generic_fmod(f32, x, y);
}

pub fn fmod(x: f64, y: f64) callconv(.C) f64 {
    return generic_fmod(f64, x, y);
}

/// fmodx - floating modulo large, returns the remainder of division for f80 types
/// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn __fmodx(a: f80, b: f80) callconv(.C) f80 {
    const T = f80;
    const Z = std.meta.Int(.unsigned, @bitSizeOf(T));

    const significandBits = math.floatMantissaBits(T);
    const fractionalBits = math.floatFractionalBits(T);
    const exponentBits = math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);

    var aRep: Z = @bitCast(a);
    var bRep: Z = @bitCast(b);

    const signA = aRep & signBit;
    var expA: i32 = @intCast((@as(Z, @bitCast(a)) >> significandBits) & maxExponent);
    var expB: i32 = @intCast((@as(Z, @bitCast(b)) >> significandBits) & maxExponent);

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
    var lowA: u64 = @as(u64, @truncate(aRep));
    var lowB: u64 = @as(u64, @truncate(bRep));

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
        return @bitCast(signA);
    } else if (expA <= 0) {
        return @bitCast((lowA >> @as(math.Log2Int(u64), @intCast(1 - expA))) | signA);
    } else {
        return @bitCast(lowA | (@as(Z, @as(u16, @intCast(expA))) << significandBits) | signA);
    }
}

/// fmodq - floating modulo large, returns the remainder of division for f128 types
/// Logic and flow heavily inspired by MUSL fmodl for 113 mantissa digits
pub fn fmodq(a: f128, b: f128) callconv(.C) f128 {
    var amod = a;
    var bmod = b;
    const aPtr_u64 = @as([*]u64, @ptrCast(&amod));
    const bPtr_u64 = @as([*]u64, @ptrCast(&bmod));
    const aPtr_u16 = @as([*]u16, @ptrCast(&amod));
    const bPtr_u16 = @as([*]u16, @ptrCast(&bmod));

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
    var expA: i32 = @intCast((aPtr_u16[exp_and_sign_index] & 0x7fff));
    var expB: i32 = @intCast((bPtr_u16[exp_and_sign_index] & 0x7fff));

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
    aPtr_u16[exp_and_sign_index] = @as(u16, @bitCast(@as(i16, @intCast(expA))));
    bPtr_u16[exp_and_sign_index] = @as(u16, @bitCast(@as(i16, @intCast(expB))));
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
        aPtr_u16[exp_and_sign_index] = @as(u16, @truncate(@as(u32, @bitCast((expA +% 120))))) | signA;
        amod *= 0x1p-120;
    } else {
        aPtr_u16[exp_and_sign_index] = @as(u16, @truncate(@as(u32, @bitCast(expA)))) | signA;
    }

    return amod;
}

pub fn fmodl(a: c_longdouble, b: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __fmodh(a, b),
        32 => return fmodf(a, b),
        64 => return fmod(a, b),
        80 => return __fmodx(a, b),
        128 => return fmodq(a, b),
        else => @compileError("unreachable"),
    }
}

inline fn generic_fmod(comptime T: type, x: T, y: T) T {
    const bits = @typeInfo(T).Float.bits;
    const uint = std.meta.Int(.unsigned, bits);
    const log2uint = math.Log2Int(uint);
    comptime assert(T == f32 or T == f64);
    const digits = if (T == f32) 23 else 52;
    const exp_bits = if (T == f32) 9 else 12;
    const bits_minus_1 = bits - 1;
    const mask = if (T == f32) 0xff else 0x7ff;
    var ux: uint = @bitCast(x);
    var uy: uint = @bitCast(y);
    var ex: i32 = @intCast((ux >> digits) & mask);
    var ey: i32 = @intCast((uy >> digits) & mask);
    const sx = if (T == f32) @as(u32, @intCast(ux & 0x80000000)) else @as(i32, @intCast(ux >> bits_minus_1));
    var i: uint = undefined;

    if (uy << 1 == 0 or math.isNan(@as(T, @bitCast(uy))) or ex == mask)
        return (x * y) / (x * y);

    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1)
            return 0 * x;
        return x;
    }

    // normalize x and y
    if (ex == 0) {
        i = ux << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ex -= 1;
            i <<= 1;
        }) {}
        ux <<= @as(log2uint, @intCast(@as(u32, @bitCast(-ex + 1))));
    } else {
        ux &= math.maxInt(uint) >> exp_bits;
        ux |= 1 << digits;
    }
    if (ey == 0) {
        i = uy << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ey -= 1;
            i <<= 1;
        }) {}
        uy <<= @as(log2uint, @intCast(@as(u32, @bitCast(-ey + 1))));
    } else {
        uy &= math.maxInt(uint) >> exp_bits;
        uy |= 1 << digits;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        i = ux -% uy;
        if (i >> bits_minus_1 == 0) {
            if (i == 0)
                return 0 * x;
            ux = i;
        }
        ux <<= 1;
    }
    i = ux -% uy;
    if (i >> bits_minus_1 == 0) {
        if (i == 0)
            return 0 * x;
        ux = i;
    }
    while (ux >> digits == 0) : ({
        ux <<= 1;
        ex -= 1;
    }) {}

    // scale result up
    if (ex > 0) {
        ux -%= 1 << digits;
        ux |= @as(uint, @as(u32, @bitCast(ex))) << digits;
    } else {
        ux >>= @as(log2uint, @intCast(@as(u32, @bitCast(-ex + 1))));
    }
    if (T == f32) {
        ux |= sx;
    } else {
        ux |= @as(uint, @intCast(sx)) << bits_minus_1;
    }
    return @bitCast(ux);
}

test "fmodf" {
    const nan_val = math.nan(f32);
    const inf_val = math.inf(f32);

    try std.testing.expect(math.isNan(fmodf(nan_val, 1.0)));
    try std.testing.expect(math.isNan(fmodf(1.0, nan_val)));
    try std.testing.expect(math.isNan(fmodf(inf_val, 1.0)));
    try std.testing.expect(math.isNan(fmodf(0.0, 0.0)));
    try std.testing.expect(math.isNan(fmodf(1.0, 0.0)));

    try std.testing.expectEqual(@as(f32, 0.0), fmodf(0.0, 2.0));
    try std.testing.expectEqual(@as(f32, -0.0), fmodf(-0.0, 2.0));

    try std.testing.expectEqual(@as(f32, -2.0), fmodf(-32.0, 10.0));
    try std.testing.expectEqual(@as(f32, -2.0), fmodf(-32.0, -10.0));
    try std.testing.expectEqual(@as(f32, 2.0), fmodf(32.0, 10.0));
    try std.testing.expectEqual(@as(f32, 2.0), fmodf(32.0, -10.0));
}

test "fmod" {
    const nan_val = math.nan(f64);
    const inf_val = math.inf(f64);

    try std.testing.expect(math.isNan(fmod(nan_val, 1.0)));
    try std.testing.expect(math.isNan(fmod(1.0, nan_val)));
    try std.testing.expect(math.isNan(fmod(inf_val, 1.0)));
    try std.testing.expect(math.isNan(fmod(0.0, 0.0)));
    try std.testing.expect(math.isNan(fmod(1.0, 0.0)));

    try std.testing.expectEqual(@as(f64, 0.0), fmod(0.0, 2.0));
    try std.testing.expectEqual(@as(f64, -0.0), fmod(-0.0, 2.0));

    try std.testing.expectEqual(@as(f64, -2.0), fmod(-32.0, 10.0));
    try std.testing.expectEqual(@as(f64, -2.0), fmod(-32.0, -10.0));
    try std.testing.expectEqual(@as(f64, 2.0), fmod(32.0, 10.0));
    try std.testing.expectEqual(@as(f64, 2.0), fmod(32.0, -10.0));
}

test {
    _ = @import("fmodq_test.zig");
    _ = @import("fmodx_test.zig");
}
