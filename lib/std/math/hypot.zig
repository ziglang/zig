// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/hypotf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/hypot.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns sqrt(x * x + y * y), avoiding unnecessary overflow and underflow.
///
/// Special Cases:
///
/// |   x   |   y   | hypot |
/// |-------|-------|-------|
/// | +inf  |  num  | +inf  |
/// |  num  | +-inf | +inf  |
/// |  nan  |  any  |  nan  |
/// |  any  |  nan  |  nan  |
pub fn hypot(x: anytype, y: anytype) @TypeOf(x, y) {
    const T = @TypeOf(x, y);
    return switch (T) {
        f32 => hypot32(x, y),
        f64 => hypot64(x, y),
        else => @compileError("hypot not implemented for " ++ @typeName(T)),
    };
}

fn hypot32(x: f32, y: f32) f32 {
    var ux = @as(u32, @bitCast(x));
    var uy = @as(u32, @bitCast(y));

    ux &= maxInt(u32) >> 1;
    uy &= maxInt(u32) >> 1;
    if (ux < uy) {
        const tmp = ux;
        ux = uy;
        uy = tmp;
    }

    var xx = @as(f32, @bitCast(ux));
    var yy = @as(f32, @bitCast(uy));
    if (uy == 0xFF << 23) {
        return yy;
    }
    if (ux >= 0xFF << 23 or uy == 0 or ux - uy >= (25 << 23)) {
        return xx + yy;
    }

    var z: f32 = 1.0;
    if (ux >= (0x7F + 60) << 23) {
        z = 0x1.0p90;
        xx *= 0x1.0p-90;
        yy *= 0x1.0p-90;
    } else if (uy < (0x7F - 60) << 23) {
        z = 0x1.0p-90;
        xx *= 0x1.0p-90;
        yy *= 0x1.0p-90;
    }

    return z * @sqrt(@as(f32, @floatCast(@as(f64, x) * x + @as(f64, y) * y)));
}

fn sq(hi: *f64, lo: *f64, x: f64) void {
    const split: f64 = 0x1.0p27 + 1.0;
    const xc = x * split;
    const xh = x - xc + xc;
    const xl = x - xh;
    hi.* = x * x;
    lo.* = xh * xh - hi.* + 2 * xh * xl + xl * xl;
}

fn hypot64(x: f64, y: f64) f64 {
    var ux = @as(u64, @bitCast(x));
    var uy = @as(u64, @bitCast(y));

    ux &= maxInt(u64) >> 1;
    uy &= maxInt(u64) >> 1;
    if (ux < uy) {
        const tmp = ux;
        ux = uy;
        uy = tmp;
    }

    const ex = ux >> 52;
    const ey = uy >> 52;
    var xx = @as(f64, @bitCast(ux));
    var yy = @as(f64, @bitCast(uy));

    // hypot(inf, nan) == inf
    if (ey == 0x7FF) {
        return yy;
    }
    if (ex == 0x7FF or uy == 0) {
        return xx;
    }

    // hypot(x, y) ~= x + y * y / x / 2 with inexact for small y/x
    if (ex - ey > 64) {
        return xx + yy;
    }

    var z: f64 = 1;
    if (ex > 0x3FF + 510) {
        z = 0x1.0p700;
        xx *= 0x1.0p-700;
        yy *= 0x1.0p-700;
    } else if (ey < 0x3FF - 450) {
        z = 0x1.0p-700;
        xx *= 0x1.0p700;
        yy *= 0x1.0p700;
    }

    var hx: f64 = undefined;
    var lx: f64 = undefined;
    var hy: f64 = undefined;
    var ly: f64 = undefined;

    sq(&hx, &lx, x);
    sq(&hy, &ly, y);

    return z * @sqrt(ly + lx + hy + hx);
}

test hypot {
    const x32: f32 = 0.0;
    const y32: f32 = -1.2;
    const x64: f64 = 0.0;
    const y64: f64 = -1.2;
    try expect(hypot(x32, y32) == hypot32(0.0, -1.2));
    try expect(hypot(x64, y64) == hypot64(0.0, -1.2));
}

test hypot32 {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f32, hypot32(0.0, -1.2), 1.2, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(0.2, -0.34), 0.394462, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(0.8923, 2.636890), 2.783772, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(1.5, 5.25), 5.460083, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(37.45, 159.835), 164.163742, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(89.123, 382.028905), 392.286865, epsilon));
    try expect(math.approxEqAbs(f32, hypot32(123123.234375, 529428.707813), 543556.875, epsilon));
}

test hypot64 {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, hypot64(0.0, -1.2), 1.2, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(0.2, -0.34), 0.394462, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(0.8923, 2.636890), 2.783772, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(1.5, 5.25), 5.460082, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(37.45, 159.835), 164.163728, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(89.123, 382.028905), 392.286876, epsilon));
    try expect(math.approxEqAbs(f64, hypot64(123123.234375, 529428.707813), 543556.885247, epsilon));
}

test "hypot32.special" {
    try expect(math.isPositiveInf(hypot32(math.inf(f32), 0.0)));
    try expect(math.isPositiveInf(hypot32(-math.inf(f32), 0.0)));
    try expect(math.isPositiveInf(hypot32(0.0, math.inf(f32))));
    try expect(math.isPositiveInf(hypot32(0.0, -math.inf(f32))));
    try expect(math.isNan(hypot32(math.nan(f32), 0.0)));
    try expect(math.isNan(hypot32(0.0, math.nan(f32))));
}

test "hypot64.special" {
    try expect(math.isPositiveInf(hypot64(math.inf(f64), 0.0)));
    try expect(math.isPositiveInf(hypot64(-math.inf(f64), 0.0)));
    try expect(math.isPositiveInf(hypot64(0.0, math.inf(f64))));
    try expect(math.isPositiveInf(hypot64(0.0, -math.inf(f64))));
    try expect(math.isNan(hypot64(math.nan(f64), 0.0)));
    try expect(math.isNan(hypot64(0.0, math.nan(f64))));
}
