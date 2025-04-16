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

// Ported from lib/libc/musl/src/math/sqrt*.c

const fenv_support = true;

pub fn __sqrth(x: f16) callconv(.c) f16 {
    // TODO: more efficient implementation
    return @floatCast(sqrtf(x));
}

pub fn sqrtf(x: f32) callconv(.c) f32 {
    // see sqrt(f64) for more detailed comments.
    var ix: u32 = @bitCast(x);
    var top: u32 = ix >> 23;

    if (top -% 1 >= 0xff - 1) {
        if (ix << 1 == 0 or ix == 0xff << 23)
            return x;
        if (ix > 0xff << 23)
            return math.nan(f32);

        // x is denormal, normalize it.
        ix = @bitCast(x * 0x1p23);
        ix -%= 23 << 23;
        top = ix >> 23;
    }

    // x = 4^e m; with int e and m in [1, 4)
    var m = (ix << 8) | (1 << 31);
    if (top % 2 != 0) m >>= 1;
    top = (top +% 0x7f) >> 1;
    top &= 0xff;

    // compute r ~ 1/sqrt(m), s ~ sqrt(m) with 2 goldschmidt iterations.
    const three: u32 = 3 << (32 - 2);
    var s: u32 = undefined;
    var d: u32 = undefined;
    var r: u32 = rsqrt_tab[@intCast((ix >> 17) % 128)];
    r <<= 16;
    // |r*sqrt(m) - 1| < 0x1p-8
    s = mul32hi(r, m);
    // |s/sqrt(m) - 1| < 0x1p-8
    d = mul32hi(r, s);
    r = mul32hi(r, three - d) << 1;
    // |r*sqrt(m) - 1| < 0x1.7bp-16
    s = mul32hi(s, three - d) << 1;
    // |s/sqrt(m) - 1| < 0x1.7bp-16
    d = mul32hi(r, s);
    s = mul32hi(s, three - d);
    // -0x1.03p-28 < s/sqrt(m) - 1 < 0x1.fp-31
    s = (s - 1) >> 6;
    // s < sqrt(m) < s + 0x1.08p-23

    // compute nearest rounded result.
    const d0 = (m << 16) -% s *% s;
    const d1 = s -% d0;
    const d2 = d1 +% s +% 1;
    s += d1 >> 31;
    const y = mkf32(top, s);
    if (fenv_support) {
        // handle rounding and inexact exception.
        var tiny: u32 = if (d2 == 0) 0 else 0x01000000;
        tiny |= (d1 ^ d2) & 0x80000000;
        const t: f32 = @bitCast(tiny);
        return y + t;
    }
    return y;
}

pub fn sqrt(x: f64) callconv(.c) f64 {
    var ix: u64 = @bitCast(x);
    var top: u64 = ix >> 52;

    if (top -% 1 >= 0x7ff - 1) {
        if (ix << 1 == 0 or ix == 0x7ff << 52)
            return x;
        if (ix > 0x7ff << 52)
            return math.nan(f64);

        // x is denormal, normalize it.
        const bias = @clz(ix) - 11;
        ix <<= @intCast(bias);
        ix += @as(u64, 52 - bias) << 52;
        top -%= bias - 1;
    }
    // argument reduction:
    //   x = 4^e m; with integer e, and m in [1, 4)
    //   m: fixed point representation [2.62]
    //   2^e is the exponent part of the result.

    var m = (ix << 11) | (1 << 63);
    if (top % 2 != 0) m >>= 1;
    top = (top +% 0x3ff) >> 1;
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

    var three: u64 = 3 << (32 - 2);
    var s: u64 = undefined;
    var d: u64 = undefined;
    var r: u64 = rsqrt_tab[@intCast((ix >> 46) % 128)];
    r <<= 16;
    // |r sqrt(m) - 1| < 0x1.fdp-9

    s = mul32hi(r, @intCast(m >> 32));
    // |s/sqrt(m) - 1| < 0x1.fdp-9
    d = mul32hi(r, s);
    r = mul32hi(r, three - d) << 1;
    // |r sqrt(m) - 1| < 0x1.7bp-16
    s = mul32hi(r, @intCast(m >> 32));
    // |s/sqrt(m) - 1| < 0x1.7bp-16
    d = mul32hi(r, s);
    r = mul32hi(r, three - d) << 1;
    // |r sqrt(m) - 1| < 0x1.3704p-29 (measured worst-case)

    three <<= 32;
    r <<= 32;

    s = mul64hi(r, m);
    d = mul64hi(r, s);
    s = mul64hi(s, three - d); // repr: 3.61
    // -0x1p-57 < s - sqrt(m) < 0x1.8001p-61
    s = (s - 2) >> 9; // repr: 12.52
    // -0x1.09p-52 < s - sqrt(m) < -0x1.fffcp-63

    // s < sqrt(m) < s + 0x1.09p-52,
    // compute nearest rounded result:
    // the nearest result to 52 bits is either s or s+0x1p-52,
    // we can decide by comparing (2^52 s + 0.5)^2 to 2^104 m.
    const d0 = (m << 42) -% s *% s;
    const d1 = s -% d0;
    const d2 = d1 +% s +% 1;

    s += d1 >> 63;
    const y = mkf64(top, s);
    if (fenv_support) {
        // handle rounding modes and inexact exception:
        // only (s+1)^2 == 2^42 m case is exact otherwise
        // add a tiny value to cause the fenv effects.
        var tiny: u64 = if (d2 == 0) 0 else 0x0010000000000000;
        tiny |= (d1 ^ d2) & 0x8000000000000000;
        const t: f64 = @bitCast(tiny);
        return y + t;
    } else return y;
}

pub fn sqrtq(x: f128) callconv(.c) f128 {
    // see sqrt(f64) for more detailed comments.
    var ix: u128 = @bitCast(x);
    var top: u64 = @intCast(ix >> 112);

    if (top -% 1 >= 0x7fff - 1) {
        // x < 0x1p-16382 or inf or NaN
        // @branchHint(.unlikely);

        if (ix << 1 == 0 or ix == 0x7fff << 112)
            return x;
        if (ix > 0x7fff << 112)
            return math.nan(f128);

        // x is denormal, normalize it.
        const bias = @clz(ix) - 15;
        ix <<= @intCast(bias);
        ix += @as(u128, 112 - bias) << 112;
        top -%= bias - 1;
    }
    // x = 4^e m; with int e and m in [1, 4)
    var ml = (ix << 15) | (1 << 127);
    if (top % 2 != 0)
        switch (comptime builtin.cpu.arch) {
            // Do the shift "by hand" to work around a bug on hexagon.
            .hexagon => {
                var lo: u64 = @truncate(ml);
                var hi: u64 = @intCast(ml >> 64);
                lo >>= 1;
                lo |= hi << 63;
                hi >>= 1;
                ml = hi;
                ml <<= 64;
                ml |= lo;
            },
            else => ml >>= 1,
        };
    top = (top +% 0x3fff) >> 1;

    // r ~= 1 / sqrt(m)
    var three: u64 = 3 << (32 - 2);
    var s: u64 = undefined;
    var d: u64 = undefined;
    var r: u64 = rsqrt_tab[@intCast((ix >> (113 - 7)) % 128)];
    r <<= 16;
    // |r sqrt(m) - 1| < 0x1p-8

    s = mul32hi(r, @intCast(ml >> 96));
    d = mul32hi(r, s);
    r = mul32hi(r, three - d) << 1;
    // |r sqrt(m) - 1| < 0x1.7bp-16, switch to 64 bit

    three <<= 32;
    r <<= 32;
    inline for (0..2) |_| {
        s = mul64hi(r, @intCast(ml >> 64));
        d = mul64hi(r, s);
        r = mul64hi(r, three - d) << 1;
    }
    // |r sqrt(m) - 1| < 0x1.a5p-31, after one iteration
    // |r sqrt(m) - 1| < 0x1.c001p-59, after two iterations
    // switch to 128 bit

    var threel: u128 = three;
    var sl: u128 = undefined;
    var dl: u128 = undefined;
    var rl: u128 = r;
    threel <<= 64;
    rl <<= 64;
    sl = mul128hi(rl, ml);
    dl = mul128hi(rl, sl);
    sl = mul128hi(sl, threel - dl); // repr: 3.125
    // -0x1p-116 < s - sqrt(m) < 0x3.8001p-125
    sl = (sl - 4) >> (125 - 112);
    // s < sqrt(m) < s + 1 ULP + tiny

    // the nearest result to 112 bits is either s or s+0x1p-112,
    // we can decide by comparing (2^112 s + 0.5)^2 to 2^(2 * 112) m.
    const d0: u128 = (ml << (2 * 112 - 126)) -% sl *% sl;
    const d1: u128 = sl -% d0;
    const d2: u128 = sl +% 1 +% d1;
    // sl += d1 >> 127;
    const y = mkf128(top, sl + (d1 >> 127));

    if (fenv_support) {
        // handle rounding modes and inexact exception.
        const d1hi: u64 = @intCast(d1 >> 64);
        const d2hi: u64 = @intCast(d2 >> 64);
        const d2lo: u64 = @truncate(d2);
        top = if (d2hi | d2lo == 0) 0 else 1;
        top |= ((d1hi ^ d2hi) & 0x8000000000000000) >> 48;
        return y + mkf128(top, 0);
    } else return y;
}

pub fn __sqrtx(x: f80) callconv(.c) f80 {
    // TODO: more efficient implementation
    return @floatCast(sqrtq(x));
}

fn _Qp_sqrt(c: *f128, a: *f128) callconv(.c) void {
    c.* = sqrtq(a.*);
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

/// Returns `a` * `b` * 2^-32
fn mul32hi(a: u64, b: u64) u32 {
    return @intCast((a * b) >> 32);
}
/// Returns `a` * `b` * 2^-64
fn mul64hi(a: u64, b: u64) u64 {
    return @intCast(mul64(a, b) >> 64);
}
/// Returns `a` * `b`
fn mul64(a: u64, b: u64) u128 {
    return math.mulWide(u64, a, b);
}

/// Returns `a` * `b` * 2^-128 with error < 7
fn mul128hi(a: u128, b: u128) u128 {
    // zig fmt: off
    const hh = mul64  (@intCast (a >> 64), @intCast (b >> 64));
    const hl = mul64hi(@intCast (a >> 64), @truncate(b));
    const lh = mul64hi(@truncate(a),       @intCast (b >> 64));
    // zig fmt: on
    return hh + hl + lh;
}

/// Returns an f32 value with exponent and sign from the lower 9 bits of
/// `top`, and significand from the lower 23 bits of `x`
fn mkf32(top: u32, x: u32) f32 {
    const Repr = packed struct { mant: u23, top: u9 };
    var repr: Repr = @bitCast(x);
    repr.top = @truncate(top);
    return @bitCast(repr);
}

/// Returns an f64 value with exponent and sign from the lower 12 bits of
/// `top`, and significand from the lower 52 bits of `x`
fn mkf64(top: u64, x: u64) f64 {
    const Repr = packed struct { mant: u52, top: u12 };
    var repr: Repr = @bitCast(x);
    repr.top = @truncate(top);
    return @bitCast(repr);
}

/// Returns an f128 value with exponent and sign from the lower 16 bits of
/// `top`, and significand from the lower 112 bits of `x`
fn mkf128(top: u64, x: u128) f128 {
    const Repr = packed struct { mant: u112, top: u16 };
    var repr: Repr = @bitCast(x);
    repr.top = @truncate(top);
    return @bitCast(repr);
}

const rsqrt_tab = [128]u16{
    0xb451, 0xb2f0, 0xb196, 0xb044, 0xaef9, 0xadb6, 0xac79, 0xab43,
    0xaa14, 0xa8eb, 0xa7c8, 0xa6aa, 0xa592, 0xa480, 0xa373, 0xa26b,
    0xa168, 0xa06a, 0x9f70, 0x9e7b, 0x9d8a, 0x9c9d, 0x9bb5, 0x9ad1,
    0x99f0, 0x9913, 0x983a, 0x9765, 0x9693, 0x95c4, 0x94f8, 0x9430,
    0x936b, 0x92a9, 0x91ea, 0x912e, 0x9075, 0x8fbe, 0x8f0a, 0x8e59,
    0x8daa, 0x8cfe, 0x8c54, 0x8bac, 0x8b07, 0x8a64, 0x89c4, 0x8925,
    0x8889, 0x87ee, 0x8756, 0x86c0, 0x862b, 0x8599, 0x8508, 0x8479,
    0x83ec, 0x8361, 0x82d8, 0x8250, 0x81c9, 0x8145, 0x80c2, 0x8040,
    0xff02, 0xfd0e, 0xfb25, 0xf947, 0xf773, 0xf5aa, 0xf3ea, 0xf234,
    0xf087, 0xeee3, 0xed47, 0xebb3, 0xea27, 0xe8a3, 0xe727, 0xe5b2,
    0xe443, 0xe2dc, 0xe17a, 0xe020, 0xdecb, 0xdd7d, 0xdc34, 0xdaf1,
    0xd9b3, 0xd87b, 0xd748, 0xd61a, 0xd4f1, 0xd3cd, 0xd2ad, 0xd192,
    0xd07b, 0xcf69, 0xce5b, 0xcd51, 0xcc4a, 0xcb48, 0xca4a, 0xc94f,
    0xc858, 0xc764, 0xc674, 0xc587, 0xc49d, 0xc3b7, 0xc2d4, 0xc1f4,
    0xc116, 0xc03c, 0xbf65, 0xbe90, 0xbdbe, 0xbcef, 0xbc23, 0xbb59,
    0xba91, 0xb9cc, 0xb90a, 0xb84a, 0xb78c, 0xb6d0, 0xb617, 0xb560,
};

test "sqrtf" {
    const V = [_]f32{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try std.testing.expectEqual(@sqrt(val), sqrtf(val));
}

test "sqrtf special" {
    try std.testing.expect(math.isPositiveInf(sqrtf(math.inf(f32))));
    try std.testing.expect(sqrtf(0.0) == 0.0);
    try std.testing.expect(sqrtf(-0.0) == -0.0);
    try std.testing.expect(math.isNan(sqrtf(-1.0)));
    try std.testing.expect(math.isNan(sqrtf(math.nan(f32))));
}

test "sqrt" {
    const V = [_]f64{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try std.testing.expectEqual(@sqrt(val), sqrt(val));
}

test "sqrt special" {
    try std.testing.expect(math.isPositiveInf(sqrt(math.inf(f64))));
    try std.testing.expect(sqrt(0.0) == 0.0);
    try std.testing.expect(sqrt(-0.0) == -0.0);
    try std.testing.expect(math.isNan(sqrt(-1.0)));
    try std.testing.expect(math.isNan(sqrt(math.nan(f64))));
}

test "sqrtq" {
    const V = [_]f128{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    const R = [_]f128{
        0e0,
        2.0221988168649871900755274601558376e0,
        2.7456797204102183847997611456248575e0,
        2.9962990399368067747997554036343434e0,
        2.3031378208682451750208657326579324e0,
        2.3837803936839249035077214695342854e0,
        7.646488461450817490535722891103117e-1,
        1.9105859478958393616294802146776404e0,
        5.637456830700109228110031227389033e-1,
        2.6740462306471598285683311010459623e0,
        1.9128294718020857595717842310189276e0,
    };

    for (V, R) |val, res|
        try std.testing.expectEqual(res, sqrtq(val));
}

test "sqrtq_special" {
    try std.testing.expect(math.isPositiveInf(sqrtq(math.inf(f128))));
    try std.testing.expect(sqrtq(0.0) == 0.0);
    try std.testing.expect(sqrtq(-0.0) == -0.0);
    try std.testing.expect(math.isNan(sqrtq(-1.0)));
    try std.testing.expect(math.isNan(sqrtq(math.nan(f128))));
}
