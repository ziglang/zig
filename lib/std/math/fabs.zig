// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/fabsf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/fabs.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the absolute value of x.
///
/// Special Cases:
///  - fabs(+-inf) = +inf
///  - fabs(nan)   = nan
pub fn fabs(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f16 => fabs16(x),
        f32 => fabs32(x),
        f64 => fabs64(x),
        f128 => fabs128(x),
        else => @compileError("fabs not implemented for " ++ @typeName(T)),
    };
}

fn fabs16(x: f16) f16 {
    var u = @bitCast(u16, x);
    u &= 0x7FFF;
    return @bitCast(f16, u);
}

fn fabs32(x: f32) f32 {
    var u = @bitCast(u32, x);
    u &= 0x7FFFFFFF;
    return @bitCast(f32, u);
}

fn fabs64(x: f64) f64 {
    var u = @bitCast(u64, x);
    u &= maxInt(u64) >> 1;
    return @bitCast(f64, u);
}

fn fabs128(x: f128) f128 {
    var u = @bitCast(u128, x);
    u &= maxInt(u128) >> 1;
    return @bitCast(f128, u);
}

test "math.fabs" {
    try expect(fabs(@as(f16, 1.0)) == fabs16(1.0));
    try expect(fabs(@as(f32, 1.0)) == fabs32(1.0));
    try expect(fabs(@as(f64, 1.0)) == fabs64(1.0));
    try expect(fabs(@as(f128, 1.0)) == fabs128(1.0));
}

test "math.fabs16" {
    try expect(fabs16(1.0) == 1.0);
    try expect(fabs16(-1.0) == 1.0);
}

test "math.fabs32" {
    try expect(fabs32(1.0) == 1.0);
    try expect(fabs32(-1.0) == 1.0);
}

test "math.fabs64" {
    try expect(fabs64(1.0) == 1.0);
    try expect(fabs64(-1.0) == 1.0);
}

test "math.fabs128" {
    try expect(fabs128(1.0) == 1.0);
    try expect(fabs128(-1.0) == 1.0);
}

test "math.fabs16.special" {
    try expect(math.isPositiveInf(fabs(math.inf(f16))));
    try expect(math.isPositiveInf(fabs(-math.inf(f16))));
    try expect(math.isNan(fabs(math.nan(f16))));
}

test "math.fabs32.special" {
    try expect(math.isPositiveInf(fabs(math.inf(f32))));
    try expect(math.isPositiveInf(fabs(-math.inf(f32))));
    try expect(math.isNan(fabs(math.nan(f32))));
}

test "math.fabs64.special" {
    try expect(math.isPositiveInf(fabs(math.inf(f64))));
    try expect(math.isPositiveInf(fabs(-math.inf(f64))));
    try expect(math.isNan(fabs(math.nan(f64))));
}

test "math.fabs128.special" {
    try expect(math.isPositiveInf(fabs(math.inf(f128))));
    try expect(math.isPositiveInf(fabs(-math.inf(f128))));
    try expect(math.isNan(fabs(math.nan(f128))));
}
