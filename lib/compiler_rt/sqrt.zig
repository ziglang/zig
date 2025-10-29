//! Ported from musl, which is MIT licensed.
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/sqrtf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/sqrt.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/sqrtl.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__sqrth, .{ .name = "__sqrth", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sqrtf, .{ .name = "sqrtf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sqrt, .{ .name = "sqrt", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__sqrtx, .{ .name = "__sqrtx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&sqrtq, .{ .name = "sqrtf128", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(&_Qp_sqrt, .{ .name = "_Qp_sqrt", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&sqrtq, .{ .name = "sqrtq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sqrtl, .{ .name = "sqrtl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __sqrth(x: f16) callconv(.c) f16 {
    var ix: u16 = @bitCast(x);
    var top = ix >> 10;

    // special case handling.
    if (top -% 0x01 >= 0x1F - 0x01) {
        @branchHint(.unlikely);
        // x < 0x1p-14 or inf or nan.
        if (ix & 0x7FFF == 0) return x;
        if (ix == 0x7C00) return x;
        if (ix > 0x7C00) return math.nan(f16);
        // x is subnormal, normalize it.
        ix = @bitCast(x * 0x1p10);
        top = (ix >> 10) -% 10;
    }

    // argument reduction:
    // x = 4^e m; with integer e, and m in [1, 4)
    // m: fixed point representation [2.14]
    // 2^e is the exponent part of the result.
    const even = (top & 1) != 0;
    const m = if (even) (ix << 4) & 0x7FFF else (ix << 5) | 0x8000;
    top = (top +% 0x0F) >> 1;

    // approximate r ~ 1/sqrt(m) and s ~ sqrt(m) when m in [1,4)
    // the fixed point representations are
    //   m: 2.14 r: 0.16, s: 2.14, d: 2.14, u: 2.14, three: 2.14
    const three: u16 = 0xC000;
    const i: usize = @intCast((ix >> 4) & 0x7F);
    const r = __rsqrt_tab[i];
    // |r*sqrt(m) - 1| < 0x1p-8
    var s = mul16(m, r);
    // |s/sqrt(m) - 1| < 0x1p-8
    const d = mul16(s, r);
    const u = three - d;
    s = mul16(s, u); // repr: 3.13
    // -0x1.20p-13 < s/sqrt(m) - 1 < 0x7Dp-16
    s = (s - 1) >> 3; // repr: 6.10
    // s < sqrt(m) < s + 0x1.24p-10

    // compute nearest rounded result:
    // the nearest result to 10 bits is either s or s+0x1p-10,
    // we can decide by comparing (2^10 s + 0.5)^2 to 2^20 m.
    const d0 = (m << 6) -% s *% s;
    const d1 = s -% d0;
    const d2 = d1 +% s +% 1;
    s += d1 >> 15;
    s &= 0x03FF;
    s |= top << 10;
    const y: f16 = @bitCast(s);

    // handle rounding modes and inexact exception:
    // only (s+1)^2 == 2^6 m case is exact otherwise
    // add a tiny value to cause the fenv effects.
    if (d2 != 0) {
        @branchHint(.likely);
        var tiny: u16 = 0x0001;
        tiny |= (d1 ^ d2) & 0x8000;
        const t: f16 = @bitCast(tiny);
        return y + t;
    }

    return y;
}

pub fn sqrtf(x: f32) callconv(.c) f32 {
    var ix: u32 = @bitCast(x);
    var top = ix >> 23;

    // special case handling.
    if (top -% 0x01 >= 0xFF - 0x01) {
        @branchHint(.unlikely);
        // x < 0x1p-126 or inf or nan.
        if (ix & 0x7FFF_FFFF == 0) return x;
        if (ix == 0x7F80_0000) return x;
        if (ix > 0x7F80_0000) return math.nan(f32);
        // x is subnormal, normalize it.
        ix = @bitCast(x * 0x1p23);
        top = (ix >> 23) -% 23;
    }

    // argument reduction:
    // x = 4^e m; with integer e, and m in [1, 4)
    // m: fixed point representation [2.30]
    // 2^e is the exponent part of the result.
    const even = (top & 1) != 0;
    const m = if (even) (ix << 7) & 0x7FFF_FFFF else (ix << 8) | 0x8000_0000;
    top = (top +% 0x7F) >> 1;

    // approximate r ~ 1/sqrt(m) and s ~ sqrt(m) when m in [1,4)
    // the fixed point representations are
    //   m: 2.30 r: 0.32, s: 2.30, d: 2.30, u: 2.30, three: 2.30
    const three: u32 = 0xC000_0000;
    var i: usize = @intCast((ix >> 17) & 0x3F);
    if (even) i += 64;
    var r = @as(u32, @intCast(__rsqrt_tab[i])) << 16;
    // |r*sqrt(m) - 1| < 0x1p-8
    var s = mul32(m, r);
    // |s/sqrt(m) - 1| < 0x1p-8
    var d = mul32(s, r);
    var u = three - d;
    r = mul32(r, u) << 1;
    // |r*sqrt(m) - 1| < 0x1.7bp-16
    s = mul32(s, u) << 1;
    // |s/sqrt(m) - 1| < 0x1.7bp-16
    d = mul32(s, r);
    u = three - d;
    s = mul32(s, u); // repr: 3.29
    // -0x1.03p-28 < s/sqrt(m) - 1 < 0x1.fp-31
    s = (s - 1) >> 6; // repr: 9.23
    // s < sqrt(m) < s + 0x1.08p-23

    // compute nearest rounded result:
    // the nearest result to 23 bits is either s or s+0x1p-23,
    // we can decide by comparing (2^23 s + 0.5)^2 to 2^46 m.
    const d0 = (m << 16) -% s *% s;
    const d1 = s -% d0;
    const d2 = d1 +% s +% 1;
    s += d1 >> 31;
    s &= 0x007F_FFFF;
    s |= top << 23;
    const y: f32 = @bitCast(s);

    // handle rounding modes and inexact exception:
    // only (s+1)^2 == 2^16 m case is exact otherwise
    // add a tiny value to cause the fenv effects.
    if (d2 != 0) {
        @branchHint(.likely);
        var tiny: u32 = 0x0100_0000;
        tiny |= (d1 ^ d2) & 0x8000_0000;
        const t: f32 = @bitCast(tiny);
        return y + t;
    }

    return y;
}

pub fn sqrt(x: f64) callconv(.c) f64 {
    var ix: u64 = @bitCast(x);
    var top = ix >> 52;

    // special case handling.
    if (top -% 0x001 >= 0x7FF - 0x001) {
        @branchHint(.unlikely);
        // x < 0x1p-1022 or inf or nan.
        if (ix & 0x7FFF_FFFF_FFFF_FFFF == 0) return x;
        if (ix == 0x7FF0_0000_0000_0000) return x;
        if (ix > 0x7FF0_0000_0000_0000) return math.nan(f64);
        // x is subnormal, normalize it.
        ix = @bitCast(x * 0x1p52);
        top = (ix >> 52) -% 52;
    }

    // argument reduction:
    // x = 4^e m; with integer e, and m in [1, 4)
    // m: fixed point representation [2.62]
    // 2^e is the exponent part of the result.
    const even = (top & 1) != 0;
    const m = if (even) (ix << 10) & 0x7FFF_FFFF_FFFF_FFFF else (ix << 11) | 0x8000_0000_0000_0000;
    top = (top +% 0x3FF) >> 1;

    // approximate r ~ 1/sqrt(m) and s ~ sqrt(m) when m in [1,4)
    //
    // initial estimate:
    // 7bit table lookup (1bit exponent and 6bit significand).
    //
    // iterative approximation:
    // using 2 goldschmidt iterations with 32bit int arithmetics
    // and a final iteration with 64bit int arithmetics.
    //
    // details:
    //
    // the relative error (e = r0 sqrt(m)-1) of a linear estimate
    // (r0 = a m + b) is |e| < 0.085955 ~ 0x1.6p-4 at best,
    // a table lookup is faster and needs one less iteration
    // 6 bit lookup table (128b) gives |e| < 0x1.f9p-8
    // 7 bit lookup table (256b) gives |e| < 0x1.fdp-9
    // for single and double prec 6bit is enough but for quad
    // prec 7bit is needed (or modified iterations). to avoid
    // one more iteration >=13bit table would be needed (16k).
    //
    // a newton-raphson iteration for r is
    //   w = r*r
    //   u = 3 - m*w
    //   r = r*u/2
    // can use a goldschmidt iteration for s at the end or
    //   s = m*r
    //
    // first goldschmidt iteration is
    //   s = m*r
    //   u = 3 - s*r
    //   r = r*u/2
    //   s = s*u/2
    // next goldschmidt iteration is
    //   u = 3 - s*r
    //   r = r*u/2
    //   s = s*u/2
    // and at the end r is not computed only s.
    //
    // they use the same amount of operations and converge at the
    // same quadratic rate, i.e. if
    //   r1 sqrt(m) - 1 = e, then
    //   r2 sqrt(m) - 1 = -3/2 e^2 - 1/2 e^3
    // the advantage of goldschmidt is that the mul for s and r
    // are independent (computed in parallel), however it is not
    // "self synchronizing": it only uses the input m in the
    // first iteration so rounding errors accumulate. at the end
    // or when switching to larger precision arithmetics rounding
    // errors dominate so the first iteration should be used.
    //
    // the fixed point representations are
    //   m: 2.30 r: 0.32, s: 2.30, d: 2.30, u: 2.30, three: 2.30
    // and after switching to 64 bit
    //   m: 2.62 r: 0.64, s: 2.62, d: 2.62, u: 2.62, three: 2.62
    const three: struct { u32, u64 } = .{
        0xC000_0000,
        0xC000_0000_0000_0000,
    };
    var r: struct { u32, u64 } = undefined;
    var s: struct { u32, u64 } = undefined;
    var d: struct { u32, u64 } = undefined;
    var u: struct { u32, u64 } = undefined;
    const i: usize = @intCast((ix >> 46) & 0x7F);
    r[0] = @intCast(__rsqrt_tab[i]);
    r[0] <<= 16;
    // |r sqrt(m) - 1| < 0x1.fdp-9
    s[0] = mul32(@intCast(m >> 32), r[0]);
    // |s/sqrt(m) - 1| < 0x1.fdp-9
    d[0] = mul32(s[0], r[0]);
    u[0] = three[0] - d[0];
    r[0] = mul32(r[0], u[0]) << 1;
    // |r sqrt(m) - 1| < 0x1.7bp-16
    s[0] = mul32(s[0], u[0]) << 1;
    // |s/sqrt(m) - 1| < 0x1.7bp-16
    d[0] = mul32(s[0], r[0]);
    u[0] = three[0] - d[0];
    r[0] = mul32(r[0], u[0]) << 1;
    // |r sqrt(m) - 1| < 0x1.3704p-29 (measured worst-case)
    r[1] = @intCast(r[0]);
    r[1] <<= 32;
    s[1] = mul64(m, r[1]);
    d[1] = mul64(s[1], r[1]);
    u[1] = three[1] - d[1];
    s[1] = mul64(s[1], u[1]); // repr: 3.61
    // -0x1p-57 < s - sqrt(m) < 0x1.8001p-61
    s[1] = (s[1] - 2) >> 9; // repr: 12.52
    // -0x1.09p-52 < s - sqrt(m) < -0x1.fffcp-63

    // s < sqrt(m) < s + 0x1.09p-52
    // compute nearest rounded result:
    // the nearest result to 52 bits is either s or s+0x1p-52,
    // we can decide by comparing (2^52 s + 0.5)^2 to 2^104 m.
    const d0 = (m << 42) -% s[1] *% s[1];
    const d1 = s[1] -% d0;
    const d2 = d1 +% s[1] +% 1;
    s[1] += d1 >> 63;
    s[1] &= 0x000F_FFFF_FFFF_FFFF;
    s[1] |= top << 52;
    const y: f64 = @bitCast(s[1]);

    // handle rounding modes and inexact exception:
    // only (s+1)^2 == 2^42 m case is exact otherwise
    // add a tiny value to cause the fenv effects.
    if (d2 != 0) {
        @branchHint(.likely);
        var tiny: u64 = 0x0010_0000_0000_0000;
        tiny |= (d1 ^ d2) & 0x8000_0000_0000_0000;
        const t: f64 = @bitCast(tiny);
        return y + t;
    }

    return y;
}

pub fn __sqrtx(x: f80) callconv(.c) f80 {
    var ix: u80 = @bitCast(x);
    var top = ix >> 64;

    // special case handling.
    if (top -% 0x0001 >= 0x7FFF - 0x0001) {
        @branchHint(.unlikely);
        // x < 0x1p-16382 or inf or nan.
        if (ix & 0x7FFF_FFFF_FFFF_FFFF_FFFF == 0) return x;
        if (ix == 0x7FFF_8000_0000_0000_0000) return x;
        if (ix > 0x7FFF_8000_0000_0000_0000) return math.nan(f80);
        // x is subnormal, normalize it.
        ix = @bitCast(x * 0x1p63);
        top = (ix >> 64) -% 63;
    }

    // argument reduction:
    // x = 4^e m; with integer e, and m in [1, 4)
    // m: fixed point representation [2.78]
    // 2^e is the exponent part of the result.
    const even = (top & 1) != 0;
    const m = if (even) (ix << 15) & 0x7FFF_FFFF_FFFF_FFFF_FFFF else ix << 16;
    top = (top +% 0x3FFF) >> 1;

    // approximate r ~ 1/sqrt(m) and s ~ sqrt(m) when m in [1,4)
    // the fixed point representations are
    //   m: 2.30 r: 0.32, s: 2.30, d: 2.30, u: 2.30, three: 2.30
    // and after switching to 64 bit
    //   m: 2.62 r: 0.64, s: 2.62, d: 2.62, u: 2.62, three: 2.62
    // and after switching to 80 bit
    //   m: 2.78 r: 0.80, s: 2.78, d: 2.78, u: 2.78, three: 2.78
    const three: struct { u32, u64, u80 } = .{
        0xC000_0000,
        0xC000_0000_0000_0000,
        0xC000_0000_0000_0000_0000,
    };
    var r: struct { u32, u64, u80 } = undefined;
    var s: struct { u32, u64, u80 } = undefined;
    var d: struct { u32, u64, u80 } = undefined;
    var u: struct { u32, u64, u80 } = undefined;
    var i: usize = @intCast((ix >> 57) & 0x3F);
    if (even) i += 64;
    r[0] = @intCast(__rsqrt_tab[i]);
    r[0] <<= 16;
    // |r sqrt(m) - 1| < 0x1p-8
    s[0] = mul32(@intCast(m >> 48), r[0]);
    d[0] = mul32(s[0], r[0]);
    u[0] = three[0] - d[0];
    r[0] = mul32(u[0], r[0]) << 1;
    // |r sqrt(m) - 1| < 0x1.7bp-16, switch to 64bit
    r[1] = @intCast(r[0]);
    r[1] <<= 32;
    s[1] = mul64(@intCast(m >> 16), r[1]);
    d[1] = mul64(s[1], r[1]);
    u[1] = three[1] - d[1];
    r[1] = mul64(u[1], r[1]) << 1;
    // |r sqrt(m) - 1| < 0x1.a5p-31
    s[1] = mul64(u[1], s[1]) << 1;
    d[1] = mul64(s[1], r[1]);
    u[1] = three[1] - d[1];
    r[1] = mul64(u[1], r[1]) << 1;
    // |r sqrt(m) - 1| < 0x1.c001p-59, switch to 80bit
    r[2] = @intCast(r[1]);
    r[2] <<= 16;
    s[2] = mul80(m, r[2]);
    d[2] = mul80(s[2], r[2]);
    u[2] = three[2] - d[2];
    s[2] = mul80(u[2], s[2]); // repr: 3.77
    s[2] = (s[2] - 4) >> 14; // repr: 17.63
    // s < sqrt(m) < s + 1 ULP + tiny

    // compute nearest rounded result:
    // the nearest result to 63 bits is either s or s+0x1p-63,
    // we can decide by comparing (2^63 s + 0.5)^2 to 2^126 m
    const d0 = (m << 48) -% mul80_tail(s[2], s[2]);
    const d1 = s[2] -% d0;
    const d2 = d1 +% s[2] +% 1;
    s[2] += d1 >> 79;
    s[2] &= 0x0000_7FFF_FFFF_FFFF_FFFF;
    s[2] |= 0x0000_8000_0000_0000_0000;
    s[2] |= top << 64;
    const y: f80 = @bitCast(s[2]);

    // handle rounding modes and inexact exception:
    // only (s+1)^2 == 2^48 m case is exact otherwise
    // add a tiny value to cause the fenv effects.
    if (d2 != 0) {
        @branchHint(.likely);
        var tiny: u80 = 0x0001_8000_0000_0000_0000;
        tiny |= (d1 ^ d2) & 0x8000_0000_0000_0000_0000;
        const t: f80 = @bitCast(tiny);
        return y + t;
    }

    return y;
}

pub fn sqrtq(x: f128) callconv(.c) f128 {
    var ix: u128 = @bitCast(x);
    var top = ix >> 112;

    // special case handling.
    if (top -% 0x0001 >= 0x7FFF - 0x0001) {
        @branchHint(.unlikely);
        // x < 0x1p-16382 or inf or nan.
        if (ix & 0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF == 0) return x;
        if (ix == 0x7FFF_0000_0000_0000_0000_0000_0000_0000) return x;
        if (ix > 0x7FFF_0000_0000_0000_0000_0000_0000_0000) return math.nan(f128);
        // x is subnormal, normalize it.
        ix = @bitCast(x * 0x1p112);
        top = (ix >> 112) -% 112;
    }

    // argument reduction:
    // x = 4^e m; with integer e, and m in [1, 4)
    // m: fixed point representation [2.126]
    // 2^e is the exponent part of the result.
    const even = (top & 1) != 0;
    const m = if (even) (ix << 14) & 0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF else (ix << 15) | 0x8000_0000_0000_0000_0000_0000_0000_0000;
    top = (top +% 0x3FFF) >> 1;

    // approximate r ~ 1/sqrt(m) and s ~ sqrt(m) when m in [1,4)
    // the fixed point representations are
    //   m: 2.30 r: 0.32, s: 2.30, d: 2.30, u: 2.30, three: 2.30
    // and after switching to 64 bit
    //   m: 2.62 r: 0.64, s: 2.62, d: 2.62, u: 2.62, three: 2.62
    // and after switching to 128 bit
    //   m: 2.126 r: 0.128, s: 2.126, d: 2.126, u: 2.126, three: 2.126
    const three: struct { u32, u64, u128 } = .{
        0xC000_0000,
        0xC000_0000_0000_0000,
        0xC000_0000_0000_0000_0000_0000_0000_0000,
    };
    var r: struct { u32, u64, u128 } = undefined;
    var s: struct { u32, u64, u128 } = undefined;
    var d: struct { u32, u64, u128 } = undefined;
    var u: struct { u32, u64, u128 } = undefined;
    const i: usize = @intCast((ix >> 106) & 0x7F);
    r[0] = @intCast(__rsqrt_tab[i]);
    r[0] <<= 16;
    // |r sqrt(m) - 1| < 0x1p-8
    s[0] = mul32(@intCast(m >> 96), r[0]);
    d[0] = mul32(s[0], r[0]);
    u[0] = three[0] - d[0];
    r[0] = mul32(u[0], r[0]) << 1;
    // |r sqrt(m) - 1| < 0x1.7bp-16, switch to 64bit
    r[1] = @intCast(r[0]);
    r[1] <<= 32;
    s[1] = mul64(@intCast(m >> 64), r[1]);
    d[1] = mul64(s[1], r[1]);
    u[1] = three[1] - d[1];
    r[1] = mul64(u[1], r[1]) << 1;
    // |r sqrt(m) - 1| < 0x1.a5p-31
    s[1] = mul64(u[1], s[1]) << 1;
    d[1] = mul64(s[1], r[1]);
    u[1] = three[1] - d[1];
    r[1] = mul64(u[1], r[1]) << 1;
    // |r sqrt(m) - 1| < 0x1.c001p-59, switch to 128bit
    r[2] = @intCast(r[1]);
    r[2] <<= 64;
    s[2] = mul128(m, r[2]);
    d[2] = mul128(s[2], r[2]);
    u[2] = three[2] - d[2];
    s[2] = mul128(u[2], s[2]); // repr: 3.125
    // -0x1p-116 < s - sqrt(m) < 0x3.8001p-125
    s[2] = (s[2] - 4) >> 13; // repr: 16.122
    // s < sqrt(m) < s + 1 ULP + tiny

    // compute nearest rounded result:
    // the nearest result to 122 bits is either s or s+0x1p-122,
    // we can decide by comparing (2^122 s + 0.5)^2 to 2^244 m
    const d0 = (m << 98) -% s[2] *% s[2];
    const d1 = s[2] -% d0;
    const d2 = d1 +% s[2] +% 1;
    s[2] += d1 >> 127;
    s[2] &= 0x0000_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
    s[2] |= top << 112;
    const y: f128 = @bitCast(s[2]);

    // handle rounding modes and inexact exception:
    // only (s+1)^2 == 2^98 m case is exact otherwise
    // add a tiny value to cause the fenv effects.
    if (d2 != 0) {
        @branchHint(.likely);
        var tiny: u128 = 0x0001_0000_0000_0000_0000_0000_0000_0000;
        tiny |= (d1 ^ d2) & 0x8000_0000_0000_0000_0000_0000_0000_0000;
        const t: f128 = @bitCast(tiny);
        return y + t;
    }

    return y;
}

fn _Qp_sqrt(c: *f128, a: *f128) callconv(.c) void {
    c.* = sqrt(@floatCast(a.*));
}

pub fn sqrtl(x: c_longdouble) callconv(.c) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __sqrth(x),
        32 => return sqrtf(x),
        64 => return sqrt(x),
        80 => return __sqrtx(x),
        128 => return sqrtq(x),
        else => @compileError("unreachable"),
    }
}

const __rsqrt_tab: [128]u16 = .{
    0xB451, 0xB2F0, 0xB196, 0xB044, 0xAEF9, 0xADB6, 0xAC79, 0xAB43,
    0xAA14, 0xA8EB, 0xA7C8, 0xA6AA, 0xA592, 0xA480, 0xA373, 0xA26B,
    0xA168, 0xA06A, 0x9F70, 0x9E7B, 0x9D8A, 0x9C9D, 0x9BB5, 0x9AD1,
    0x99F0, 0x9913, 0x983A, 0x9765, 0x9693, 0x95C4, 0x94F8, 0x9430,
    0x936B, 0x92A9, 0x91EA, 0x912E, 0x9075, 0x8FBE, 0x8F0A, 0x8E59,
    0x8DAA, 0x8CFE, 0x8C54, 0x8BAC, 0x8B07, 0x8A64, 0x89C4, 0x8925,
    0x8889, 0x87EE, 0x8756, 0x86C0, 0x862B, 0x8599, 0x8508, 0x8479,
    0x83EC, 0x8361, 0x82D8, 0x8250, 0x81C9, 0x8145, 0x80C2, 0x8040,
    0xFF02, 0xFD0E, 0xFB25, 0xF947, 0xF773, 0xF5AA, 0xF3EA, 0xF234,
    0xF087, 0xEEE3, 0xED47, 0xEBB3, 0xEA27, 0xE8A3, 0xE727, 0xE5B2,
    0xE443, 0xE2DC, 0xE17A, 0xE020, 0xDECB, 0xDD7D, 0xDC34, 0xDAF1,
    0xD9B3, 0xD87B, 0xD748, 0xD61A, 0xD4F1, 0xD3CD, 0xD2AD, 0xD192,
    0xD07B, 0xCF69, 0xCE5B, 0xCD51, 0xCC4A, 0xCB48, 0xCA4A, 0xC94F,
    0xC858, 0xC764, 0xC674, 0xC587, 0xC49D, 0xC3B7, 0xC2D4, 0xC1F4,
    0xC116, 0xC03C, 0xBF65, 0xBE90, 0xBDBE, 0xBCEF, 0xBC23, 0xBB59,
    0xBA91, 0xB9CC, 0xB90A, 0xB84A, 0xB78C, 0xB6D0, 0xB617, 0xB560,
};

inline fn mul16(a: u16, b: u16) u16 {
    return @intCast(@as(u32, @intCast(a)) * @as(u32, @intCast(b)) >> 16);
}

inline fn mul32(a: u32, b: u32) u32 {
    return @intCast(@as(u64, @intCast(a)) * @as(u64, @intCast(b)) >> 32);
}

inline fn mul64(a: u64, b: u64) u64 {
    return @intCast(@as(u128, @intCast(a)) * @as(u128, @intCast(b)) >> 64);
}

inline fn mul80(a: u80, b: u80) u80 {
    const ahi = a >> 40;
    const alo = a & 0xFF_FFFF_FFFF;
    const bhi = b >> 40;
    const blo = b & 0xFF_FFFF_FFFF;
    return ahi * bhi + (ahi * blo >> 40) + (alo * bhi >> 40);
}

inline fn mul128(a: u128, b: u128) u128 {
    const ahi = a >> 64;
    const alo = a & 0xFFFF_FFFF_FFFF_FFFF;
    const bhi = b >> 64;
    const blo = b & 0xFFFF_FFFF_FFFF_FFFF;
    return ahi * bhi + (ahi * blo >> 64) + (alo * bhi >> 64);
}

inline fn mul80_tail(a: u80, b: u80) u80 {
    const ahi = a >> 40;
    const alo = a & 0xFF_FFFF_FFFF;
    const bhi = b >> 40;
    const blo = b & 0xFF_FFFF_FFFF;
    return alo * blo +% ((ahi * blo) << 40) +% ((alo * bhi) << 40);
}

test "__sqrth" {
    // sqrt(±0) is ±0
    try std.testing.expectEqual(__sqrth(0x0.0p0), 0x0.0p0);
    try std.testing.expectEqual(__sqrth(-0x0.0p0), -0x0.0p0);
    // sqrt(+max) is finite
    try std.testing.expectEqual(__sqrth(0x1.FFCp15), 0x1.FFCp7);
    // sqrt(4)=2
    try std.testing.expectEqual(__sqrth(0x1p2), 0x1p1);
    // sqrt(x) for x=1, 1±ulp
    try std.testing.expectEqual(__sqrth(0x1p0), 0x1p0);
    try std.testing.expectEqual(__sqrth(0x1.004p0), 0x1p0);
    try std.testing.expectEqual(__sqrth(0x1.FF8p-1), 0x1.FFCp-1);
    // sqrt(+min) is non-zero
    try std.testing.expectEqual(__sqrth(0x1p-14), 0x1p-7);
    // sqrt(min subnormal) is non-zero
    try std.testing.expectEqual(__sqrth(0x0.004p-14), 0x1p-12);
    // sqrt(inf) is inf
    try std.testing.expect(math.isInf(__sqrth(math.inf(f16))));
    // sqrt(nan) is nan
    try std.testing.expect(math.isNan(__sqrth(math.nan(f16))));
    // sqrt(-ve) is nan
    try std.testing.expect(math.isNan(__sqrth(-0x1p-14)));
    try std.testing.expect(math.isNan(__sqrth(-0x1p+0)));
    try std.testing.expect(math.isNan(__sqrth(-math.inf(f16))));
    // random arguments
    try std.testing.expectEqual(__sqrth(0x1.1p14), 0x1.08p7);
    try std.testing.expectEqual(__sqrth(0x1.C9p-12), 0x1.56p-6);
    try std.testing.expectEqual(__sqrth(0x1.CE8p-7), 0x1.E68p-4);
    try std.testing.expectEqual(__sqrth(0x1.134p-7), 0x1.778p-4);
    try std.testing.expectEqual(__sqrth(0x1.E9Cp-10), 0x1.62p-5);
    try std.testing.expectEqual(__sqrth(0x1.3Dp9), 0x1.92Cp4);
    try std.testing.expectEqual(__sqrth(0x1.AA4p8), 0x1.4A4p4);
    try std.testing.expectEqual(__sqrth(0x1.8A8p4), 0x1.3DCp2);
    try std.testing.expectEqual(__sqrth(0x1.8Fp-7), 0x1.C4p-4);
    try std.testing.expectEqual(__sqrth(0x1.584p-11), 0x1.A3Cp-6);
}

test "sqrtf" {
    // sqrt(±0) is ±0
    try std.testing.expectEqual(sqrtf(0x0.0p0), 0x0.0p0);
    try std.testing.expectEqual(sqrtf(-0x0.0p0), -0x0.0p0);
    // sqrt(+max) is finite
    try std.testing.expectEqual(sqrtf(0x1.FFFFFEp127), 0x1.FFFFFEp63);
    // sqrt(4)=2
    try std.testing.expectEqual(sqrtf(0x1p2), 0x1p1);
    // sqrt(x) for x=1, 1±ulp
    try std.testing.expectEqual(sqrtf(0x1p0), 0x1p0);
    try std.testing.expectEqual(sqrtf(0x1.000002p0), 0x1p0);
    try std.testing.expectEqual(sqrtf(0x1.FFFFFEp-1), 0x1.FFFFFEp-1);
    // sqrt(+min) is non-zero
    try std.testing.expectEqual(sqrtf(0x1p-126), 0x1p-63);
    // sqrt(min subnormal) is non-zero
    try std.testing.expectEqual(sqrtf(0x0.000002p-126), 0x1.6a09e6p-75);
    // sqrt(inf) is inf
    try std.testing.expect(math.isInf(sqrtf(math.inf(f32))));
    // sqrt(nan) is nan
    try std.testing.expect(math.isNan(sqrtf(math.nan(f32))));
    // sqrt(-ve) is nan
    try std.testing.expect(math.isNan(sqrtf(-0x1p-149)));
    try std.testing.expect(math.isNan(sqrtf(-0x1p0)));
    try std.testing.expect(math.isNan(sqrtf(-math.inf(f32))));
    // random arguments
    try std.testing.expectEqual(sqrtf(0x1.4DD57Ep77), 0x1.9D6DA8p38);
    try std.testing.expectEqual(sqrtf(0x1.871848p102), 0x1.3C6AFAp51);
    try std.testing.expectEqual(sqrtf(0x1.A1D748p-112), 0x1.470EFCp-56);
    try std.testing.expectEqual(sqrtf(0x1.E626C2p18), 0x1.60C80Ep9);
    try std.testing.expectEqual(sqrtf(0x1.E80E66p-29), 0x1.F3E282p-15);
    try std.testing.expectEqual(sqrtf(0x1.B47204p89), 0x1.D8B732p44);
    try std.testing.expectEqual(sqrtf(0x1.77F45p15), 0x1.B6BC3Ap7);
    try std.testing.expectEqual(sqrtf(0x1.AD5F5p-48), 0x1.4B8A72p-24);
    try std.testing.expectEqual(sqrtf(0x1.91A39p-76), 0x1.40A7A8p-38);
    try std.testing.expectEqual(sqrtf(0x1.DAE088p79), 0x1.ED16DCp39);
}

test "sqrt" {
    // sqrt(±0) is ±0
    try std.testing.expectEqual(sqrt(0x0.0p0), 0x0.0p0);
    try std.testing.expectEqual(sqrt(-0x0.0p0), -0x0.0p0);
    // sqrt(+max) is finite
    try std.testing.expectEqual(sqrt(math.floatMax(f64)), 0x1.FFFFFFFFFFFFFp511);
    // sqrt(4)=2
    try std.testing.expectEqual(sqrt(0x1p2), 0x1p1);
    // sqrt(x) for x=1, 1±ulp
    try std.testing.expectEqual(sqrt(0x1p0), 0x1p0);
    try std.testing.expectEqual(sqrt(0x1p0 + math.floatEps(f64)), 0x1p0);
    try std.testing.expectEqual(sqrt(0x1p0 - math.floatEps(f64)), 0x1.FFFFFFFFFFFFFp-1);
    // sqrt(+min) is non-zero
    try std.testing.expectEqual(sqrt(math.floatMin(f64)), 0x1p-511);
    // sqrt(min subnormal) is non-zero
    try std.testing.expectEqual(sqrt(math.floatTrueMin(f64)), 0x1p-537);
    // sqrt(inf) is inf
    try std.testing.expect(math.isInf(sqrt(math.inf(f64))));
    // sqrt(nan) is nan
    try std.testing.expect(math.isNan(sqrt(math.nan(f64))));
    // sqrt(-ve) is nan
    try std.testing.expect(math.isNan(sqrt(-0x1p-1074)));
    try std.testing.expect(math.isNan(sqrt(-0x1p0)));
    try std.testing.expect(math.isNan(sqrt(-math.inf(f64))));
    // random arguments
    try std.testing.expectEqual(sqrt(0x1.27D3510D4789Bp471), 0x1.852E97E58CFB7p235);
    try std.testing.expectEqual(sqrt(0x1.8C4FCD5A07846p791), 0x1.C27504E56D938p395);
    try std.testing.expectEqual(sqrt(0x1.B1B69324F96E7p-137), 0x1.D73BD0414D8BFp-69);
    try std.testing.expectEqual(sqrt(0x1.1CBD179A811FEp278), 0x1.0DFCB9A114A61p139);
    try std.testing.expectEqual(sqrt(0x1.1D0C7EFB04A56p917), 0x1.7E0708A25DDCDp458);
    try std.testing.expectEqual(sqrt(0x1.21B355DA8C94Bp-249), 0x1.8121CBE2608E3p-125);
    try std.testing.expectEqual(sqrt(0x1.63024D4C5E987p487), 0x1.AA56AEA589DCDp243);
    try std.testing.expectEqual(sqrt(0x1.45AC3BE941F6Ep339), 0x1.9857F3F453E2Dp169);
    try std.testing.expectEqual(sqrt(0x1.3B719C733AA24p267), 0x1.91E12E3AC8F71p133);
    try std.testing.expectEqual(sqrt(0x1.0B150433A2275p357), 0x1.71CAB87F8277Cp178);
}

test "__sqrtx" {
    // sqrt(±0) is ±0
    try std.testing.expectEqual(__sqrtx(0x0.0p0), 0x0.0p0);
    try std.testing.expectEqual(__sqrtx(-0x0.0p0), -0x0.0p0);
    // sqrt(+max) is finite
    try std.testing.expectEqual(__sqrtx(math.floatMax(f80)), 0x1.FFFFFFFFFFFFFFFEp8191);
    // sqrt(4)=2
    try std.testing.expectEqual(__sqrtx(0x1p2), 0x1p1);
    // sqrt(x) for x=1, 1±ulp
    try std.testing.expectEqual(__sqrtx(0x1p0), 0x1p0);
    try std.testing.expectEqual(__sqrtx(0x1p0 + math.floatEps(f80)), 0x1p0);
    try std.testing.expectEqual(__sqrtx(0x1p0 - math.floatEps(f80)), 0x1.FFFFFFFFFFFFFFFEp-1);
    // sqrt(+min) is non-zero
    try std.testing.expectEqual(__sqrtx(math.floatMin(f80)), 0x1p-8191);
    // sqrt(min subnormal) is non-zero
    try std.testing.expectEqual(__sqrtx(math.floatTrueMin(f80)), 0x1.6A09E667F3BCC908p-8223);
    // sqrt(inf) is inf
    try std.testing.expect(math.isInf(__sqrtx(math.inf(f80))));
    // sqrt(nan) is nan
    try std.testing.expect(math.isNan(__sqrtx(math.nan(f80))));
    // sqrt(-ve) is nan
    try std.testing.expect(math.isNan(__sqrtx(-0x1p-16442)));
    try std.testing.expect(math.isNan(__sqrtx(-0x1p0)));
    try std.testing.expect(math.isNan(__sqrtx(-math.inf(f80))));
    // random arguments
    try std.testing.expectEqual(__sqrtx(0x1.087F3953486918A4p15482), 0x1.0436BBE03D02F32p7741);
    try std.testing.expectEqual(__sqrtx(0x1.530CF9E2AE84D8Fp-6330), 0x1.269CFEF51933BE58p-3165);
    try std.testing.expectEqual(__sqrtx(0x1.3F971515EADD574Ap5713), 0x1.9483232AB780B006p2856);
    try std.testing.expectEqual(__sqrtx(0x1.4CC0DC7379222954p864), 0x1.23DD4D0A4758C2Cp432);
    try std.testing.expectEqual(__sqrtx(0x1.920E5649559A839Ep-3181), 0x1.C5B5BC0F98DD83D2p-1591);
    try std.testing.expectEqual(__sqrtx(0x1.2E59726F87CD1746p-629), 0x1.8973327E95CB350Cp-315);
    try std.testing.expectEqual(__sqrtx(0x1.D3A16391F57B4D64p-9034), 0x1.59FF08B7DEEF5DB2p-4517);
    try std.testing.expectEqual(__sqrtx(0x1.E7053D8DAA49BCEEp-11411), 0x1.F35AA3EA5E18E344p-5706);
    try std.testing.expectEqual(__sqrtx(0x1.797ED0B05DD4A984p7521), 0x1.B7A22E40C6A7867Ap3760);
    try std.testing.expectEqual(__sqrtx(0x1.FC50806445C7226Ap15371), 0x1.FE2766142653F5BEp7685);
}

test "sqrtq" {
    // sqrt(±0) is ±0
    try std.testing.expectEqual(sqrtq(0x0.0p0), 0x0.0p0);
    try std.testing.expectEqual(sqrtq(-0x0.0p0), -0x0.0p0);
    // sqrt(+max) is finite
    try std.testing.expectEqual(sqrtq(math.floatMax(f128)), 0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp8191);
    // sqrt(4)=2
    try std.testing.expectEqual(sqrtq(0x1p2), 0x1p1);
    // sqrt(x) for x=1, 1±ulp
    try std.testing.expectEqual(sqrtq(0x1p0), 0x1p0);
    try std.testing.expectEqual(sqrtq(0x1p0 + math.floatEps(f128)), 0x1p0);
    try std.testing.expectEqual(sqrtq(0x1p0 - math.floatEps(f128)), 0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp-1);
    // sqrt(+min) is non-zero
    try std.testing.expectEqual(sqrtq(math.floatMin(f128)), 0x1p-8191);
    // sqrt(min subnormal) is non-zero
    try std.testing.expectEqual(sqrtq(math.floatTrueMin(f128)), 0x1p-8247);
    // sqrt(inf) is inf
    try std.testing.expect(math.isInf(sqrtq(math.inf(f128))));
    // sqrt(nan) is nan
    try std.testing.expect(math.isNan(sqrtq(math.nan(f128))));
    // sqrt(-ve) is nan
    try std.testing.expect(math.isNan(sqrtq(-0x1p-16442)));
    try std.testing.expect(math.isNan(sqrtq(-0x1p0)));
    try std.testing.expect(math.isNan(sqrtq(-math.inf(f128))));
    // random arguments
    try std.testing.expectEqual(sqrtq(0x1.B6942D29A331751600C9F3AF7E5Fp3363), 0x1.D9DE9AFEF0F2D25586A50CA39D4Dp1681);
    try std.testing.expectEqual(sqrtq(0x1.5E65C405F84D471A8070ADD7A42Dp11765), 0x1.A78F7F9452B4D9EC2403C81D9D42p5882);
    try std.testing.expectEqual(sqrtq(0x1.B42334D68F8016D8AE6F5E22B044p-5624), 0x1.4E247A7F2FF2A325E9377BB09C8p-2812);
    try std.testing.expectEqual(sqrtq(0x1.E61715047F80F2E0B9382B38E06Bp10062), 0x1.60C25D9DFDC0116B78EF5AFDE0E9p5031);
    try std.testing.expectEqual(sqrtq(0x1.2ED0B53B494CB55A7B04E653D40Ep-1026), 0x1.166CE78D658D2453D700B04C5748p-513);
    try std.testing.expectEqual(sqrtq(0x1.1BA756B9790E78A4E6F0B083AA89p1835), 0x1.7D1767EA3303DB7A46940033988p917);
    try std.testing.expectEqual(sqrtq(0x1.5B6C574319C1120335C8E1609704p4512), 0x1.2A3A8A415BB1648C548FBA2A4182p2256);
    try std.testing.expectEqual(sqrtq(0x1.FF91E8CDEE1552A2B74E77B602Ep14953), 0x1.FFC8F171267D4FE75CBE7AB4D851p7476);
    try std.testing.expectEqual(sqrtq(0x1.9B1837CFC629A1B6B1BB97099E7Dp2892), 0x1.4468511B909EAF8641BD59105A6Bp1446);
    try std.testing.expectEqual(sqrtq(0x1.0E2115475E64A92340914E7F7B37p-13951), 0x1.73E536F82F414134012F55BA5368p-6976);
}
