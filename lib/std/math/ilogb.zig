// Ported from musl, which is MIT licensed.
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/ilogbl.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/ilogbf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/ilogb.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

/// Returns the binary exponent of x as an integer.
///
/// Special Cases:
///  - ilogb(+-inf) = maxInt(i32)
///  - ilogb(+-0)   = minInt(i32)
///  - ilogb(nan)   = minInt(i32)
pub fn ilogb(x: anytype) i32 {
    const T = @TypeOf(x);
    return ilogbX(T, x);
}

pub const fp_ilogbnan = minInt(i32);
pub const fp_ilogb0 = minInt(i32);

fn ilogbX(comptime T: type, x: T) i32 {
    const typeWidth = @typeInfo(T).Float.bits;
    const significandBits = math.floatMantissaBits(T);
    const exponentBits = math.floatExponentBits(T);

    const Z = std.meta.Int(.unsigned, typeWidth);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const absMask = signBit - 1;

    const u = @as(Z, @bitCast(x)) & absMask;
    const e: i32 = @intCast(u >> significandBits);

    if (e == 0) {
        if (u == 0) {
            math.raiseInvalid();
            return fp_ilogb0;
        }

        // offset sign bit, exponent bits, and integer bit (if present) + bias
        const offset = 1 + exponentBits + @as(comptime_int, @intFromBool(T == f80)) - exponentBias;
        return offset - @as(i32, @intCast(@clz(u)));
    }

    if (e == maxExponent) {
        math.raiseInvalid();
        if (u > @as(Z, @bitCast(math.inf(T)))) {
            return fp_ilogbnan; // u is a NaN
        } else return maxInt(i32);
    }

    return e - exponentBias;
}

test "type dispatch" {
    try expect(ilogb(@as(f32, 0.2)) == ilogbX(f32, 0.2));
    try expect(ilogb(@as(f64, 0.2)) == ilogbX(f64, 0.2));
}

test "16" {
    try expect(ilogbX(f16, 0.0) == fp_ilogb0);
    try expect(ilogbX(f16, 0.5) == -1);
    try expect(ilogbX(f16, 0.8923) == -1);
    try expect(ilogbX(f16, 10.0) == 3);
    try expect(ilogbX(f16, -65504) == 15);
    try expect(ilogbX(f16, 2398.23) == 11);

    try expect(ilogbX(f16, 0x1p-1) == -1);
    try expect(ilogbX(f16, 0x1p-17) == -17);
    try expect(ilogbX(f16, 0x1p-24) == -24);
}

test "32" {
    try expect(ilogbX(f32, 0.0) == fp_ilogb0);
    try expect(ilogbX(f32, 0.5) == -1);
    try expect(ilogbX(f32, 0.8923) == -1);
    try expect(ilogbX(f32, 10.0) == 3);
    try expect(ilogbX(f32, -123984) == 16);
    try expect(ilogbX(f32, 2398.23) == 11);

    try expect(ilogbX(f32, 0x1p-1) == -1);
    try expect(ilogbX(f32, 0x1p-122) == -122);
    try expect(ilogbX(f32, 0x1p-127) == -127);
}

test "64" {
    try expect(ilogbX(f64, 0.0) == fp_ilogb0);
    try expect(ilogbX(f64, 0.5) == -1);
    try expect(ilogbX(f64, 0.8923) == -1);
    try expect(ilogbX(f64, 10.0) == 3);
    try expect(ilogbX(f64, -123984) == 16);
    try expect(ilogbX(f64, 2398.23) == 11);

    try expect(ilogbX(f64, 0x1p-1) == -1);
    try expect(ilogbX(f64, 0x1p-127) == -127);
    try expect(ilogbX(f64, 0x1p-1012) == -1012);
    try expect(ilogbX(f64, 0x1p-1023) == -1023);
}

test "80" {
    try expect(ilogbX(f80, 0.0) == fp_ilogb0);
    try expect(ilogbX(f80, 0.5) == -1);
    try expect(ilogbX(f80, 0.8923) == -1);
    try expect(ilogbX(f80, 10.0) == 3);
    try expect(ilogbX(f80, -123984) == 16);
    try expect(ilogbX(f80, 2398.23) == 11);

    try expect(ilogbX(f80, 0x1p-1) == -1);
    try expect(ilogbX(f80, 0x1p-127) == -127);
    try expect(ilogbX(f80, 0x1p-1023) == -1023);
    try expect(ilogbX(f80, 0x1p-16383) == -16383);
}

test "128" {
    try expect(ilogbX(f128, 0.0) == fp_ilogb0);
    try expect(ilogbX(f128, 0.5) == -1);
    try expect(ilogbX(f128, 0.8923) == -1);
    try expect(ilogbX(f128, 10.0) == 3);
    try expect(ilogbX(f128, -123984) == 16);
    try expect(ilogbX(f128, 2398.23) == 11);

    try expect(ilogbX(f128, 0x1p-1) == -1);
    try expect(ilogbX(f128, 0x1p-127) == -127);
    try expect(ilogbX(f128, 0x1p-1023) == -1023);
    try expect(ilogbX(f128, 0x1p-16383) == -16383);
}

test "16 special" {
    try expect(ilogbX(f16, math.inf(f16)) == maxInt(i32));
    try expect(ilogbX(f16, -math.inf(f16)) == maxInt(i32));
    try expect(ilogbX(f16, 0.0) == minInt(i32));
    try expect(ilogbX(f16, math.nan(f16)) == fp_ilogbnan);
}

test "32 special" {
    try expect(ilogbX(f32, math.inf(f32)) == maxInt(i32));
    try expect(ilogbX(f32, -math.inf(f32)) == maxInt(i32));
    try expect(ilogbX(f32, 0.0) == minInt(i32));
    try expect(ilogbX(f32, math.nan(f32)) == fp_ilogbnan);
}

test "64 special" {
    try expect(ilogbX(f64, math.inf(f64)) == maxInt(i32));
    try expect(ilogbX(f64, -math.inf(f64)) == maxInt(i32));
    try expect(ilogbX(f64, 0.0) == minInt(i32));
    try expect(ilogbX(f64, math.nan(f64)) == fp_ilogbnan);
}

test "80 special" {
    try expect(ilogbX(f80, math.inf(f80)) == maxInt(i32));
    try expect(ilogbX(f80, -math.inf(f80)) == maxInt(i32));
    try expect(ilogbX(f80, 0.0) == minInt(i32));
    try expect(ilogbX(f80, math.nan(f80)) == fp_ilogbnan);
}

test "128 special" {
    try expect(ilogbX(f128, math.inf(f128)) == maxInt(i32));
    try expect(ilogbX(f128, -math.inf(f128)) == maxInt(i32));
    try expect(ilogbX(f128, 0.0) == minInt(i32));
    try expect(ilogbX(f128, math.nan(f128)) == fp_ilogbnan);
}
