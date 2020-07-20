// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/truncf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/trunc.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the integer value of x.
///
/// Special Cases:
///  - trunc(+-0)   = +-0
///  - trunc(+-inf) = +-inf
///  - trunc(nan)   = nan
pub fn trunc(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => trunc32(x),
        f64 => trunc64(x),
        f128 => trunc128(x),
        else => @compileError("trunc not implemented for " ++ @typeName(T)),
    };
}

fn trunc32(x: f32) f32 {
    const u = @bitCast(u32, x);
    var e = @intCast(i32, ((u >> 23) & 0xFF)) - 0x7F + 9;
    var m: u32 = undefined;

    if (e >= 23 + 9) {
        return x;
    }
    if (e < 9) {
        e = 1;
    }

    m = @as(u32, maxInt(u32)) >> @intCast(u5, e);
    if (u & m == 0) {
        return x;
    } else {
        math.forceEval(x + 0x1p120);
        return @bitCast(f32, u & ~m);
    }
}

fn trunc64(x: f64) f64 {
    const u = @bitCast(u64, x);
    var e = @intCast(i32, ((u >> 52) & 0x7FF)) - 0x3FF + 12;
    var m: u64 = undefined;

    if (e >= 52 + 12) {
        return x;
    }
    if (e < 12) {
        e = 1;
    }

    m = @as(u64, maxInt(u64)) >> @intCast(u6, e);
    if (u & m == 0) {
        return x;
    } else {
        math.forceEval(x + 0x1p120);
        return @bitCast(f64, u & ~m);
    }
}

fn trunc128(x: f128) f128 {
    const u = @bitCast(u128, x);
    var e = @intCast(i32, ((u >> 112) & 0x7FFF)) - 0x3FFF + 16;
    var m: u128 = undefined;

    if (e >= 112 + 16) {
        return x;
    }
    if (e < 16) {
        e = 1;
    }

    m = @as(u128, maxInt(u128)) >> @intCast(u7, e);
    if (u & m == 0) {
        return x;
    } else {
        math.forceEval(x + 0x1p120);
        return @bitCast(f128, u & ~m);
    }
}

test "math.trunc" {
    expect(trunc(@as(f32, 1.3)) == trunc32(1.3));
    expect(trunc(@as(f64, 1.3)) == trunc64(1.3));
    expect(trunc(@as(f128, 1.3)) == trunc128(1.3));
}

test "math.trunc32" {
    expect(trunc32(1.3) == 1.0);
    expect(trunc32(-1.3) == -1.0);
    expect(trunc32(0.2) == 0.0);
}

test "math.trunc64" {
    expect(trunc64(1.3) == 1.0);
    expect(trunc64(-1.3) == -1.0);
    expect(trunc64(0.2) == 0.0);
}

test "math.trunc128" {
    expect(trunc128(1.3) == 1.0);
    expect(trunc128(-1.3) == -1.0);
    expect(trunc128(0.2) == 0.0);
}

test "math.trunc32.special" {
    expect(trunc32(0.0) == 0.0); // 0x3F800000
    expect(trunc32(-0.0) == -0.0);
    expect(math.isPositiveInf(trunc32(math.inf(f32))));
    expect(math.isNegativeInf(trunc32(-math.inf(f32))));
    expect(math.isNan(trunc32(math.nan(f32))));
}

test "math.trunc64.special" {
    expect(trunc64(0.0) == 0.0);
    expect(trunc64(-0.0) == -0.0);
    expect(math.isPositiveInf(trunc64(math.inf(f64))));
    expect(math.isNegativeInf(trunc64(-math.inf(f64))));
    expect(math.isNan(trunc64(math.nan(f64))));
}

test "math.trunc128.special" {
    expect(trunc128(0.0) == 0.0);
    expect(trunc128(-0.0) == -0.0);
    expect(math.isPositiveInf(trunc128(math.inf(f128))));
    expect(math.isNegativeInf(trunc128(-math.inf(f128))));
    expect(math.isNan(trunc128(math.nan(f128))));
}
