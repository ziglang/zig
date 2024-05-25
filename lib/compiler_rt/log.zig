//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/lnf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/ln.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__logh, .{ .name = "__logh", .linkage = common.linkage, .visibility = common.visibility });
    @export(&logf, .{ .name = "logf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&log, .{ .name = "log", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__logx, .{ .name = "__logx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&logq, .{ .name = "logf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&logq, .{ .name = "logq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&logl, .{ .name = "logl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __logh(a: f16) callconv(.c) f16 {
    // TODO: more efficient implementation
    return @floatCast(logf(a));
}

pub fn logf(x_: f32) callconv(.c) f32 {
    const ln2_hi: f32 = 6.9313812256e-01;
    const ln2_lo: f32 = 9.0580006145e-06;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    var x = x_;
    var ix: u32 = @bitCast(x);
    var k: i32 = 0;

    // x < 2^(-126)
    if (ix < 0x00800000 or ix >> 31 != 0) {
        // log(+-0) = -inf
        if (ix << 1 == 0) {
            return -math.inf(f32);
        }
        // log(-#) = nan
        if (ix >> 31 != 0) {
            return math.nan(f32);
        }

        // subnormal, scale x
        k -= 25;
        x *= 0x1.0p25;
        ix = @bitCast(x);
    } else if (ix >= 0x7F800000) {
        return x;
    } else if (ix == 0x3F800000) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    ix += 0x3F800000 - 0x3F3504F3;
    k += @as(i32, @intCast(ix >> 23)) - 0x7F;
    ix = (ix & 0x007FFFFF) + 0x3F3504F3;
    x = @bitCast(ix);

    const f = x - 1.0;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * Lg4);
    const t2 = z * (Lg1 + w * Lg3);
    const R = t2 + t1;
    const hfsq = 0.5 * f * f;
    const dk: f32 = @floatFromInt(k);

    return s * (hfsq + R) + dk * ln2_lo - hfsq + f + dk * ln2_hi;
}

pub fn log(x_: f64) callconv(.c) f64 {
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const Lg1: f64 = 6.666666666666735130e-01;
    const Lg2: f64 = 3.999999999940941908e-01;
    const Lg3: f64 = 2.857142874366239149e-01;
    const Lg4: f64 = 2.222219843214978396e-01;
    const Lg5: f64 = 1.818357216161805012e-01;
    const Lg6: f64 = 1.531383769920937332e-01;
    const Lg7: f64 = 1.479819860511658591e-01;

    var x = x_;
    var ix: u64 = @bitCast(x);
    var hx: u32 = @intCast(ix >> 32);
    var k: i32 = 0;

    if (hx < 0x00100000 or hx >> 31 != 0) {
        // log(+-0) = -inf
        if (ix << 1 == 0) {
            return -math.inf(f64);
        }
        // log(-#) = nan
        if (hx >> 31 != 0) {
            return math.nan(f64);
        }

        // subnormal, scale x
        k -= 54;
        x *= 0x1p54;
        hx = @intCast(@as(u64, @bitCast(x)) >> 32);
    } else if (hx >= 0x7FF00000) {
        return x;
    } else if (hx == 0x3FF00000 and ix << 32 == 0) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    hx += 0x3FF00000 - 0x3FE6A09E;
    k += @as(i32, @intCast(hx >> 20)) - 0x3FF;
    hx = (hx & 0x000FFFFF) + 0x3FE6A09E;
    ix = (@as(u64, hx) << 32) | (ix & 0xFFFFFFFF);
    x = @bitCast(ix);

    const f = x - 1.0;
    const hfsq = 0.5 * f * f;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * (Lg4 + w * Lg6));
    const t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)));
    const R = t2 + t1;
    const dk: f64 = @floatFromInt(k);

    return s * (hfsq + R) + dk * ln2_lo - hfsq + f + dk * ln2_hi;
}

pub fn __logx(a: f80) callconv(.c) f80 {
    // TODO: more efficient implementation
    return @floatCast(logq(a));
}

pub fn logq(a: f128) callconv(.c) f128 {
    // TODO: more correct implementation
    return log(@floatCast(a));
}

pub fn logl(x: c_longdouble) callconv(.c) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __logh(x),
        32 => return logf(x),
        64 => return log(x),
        80 => return __logx(x),
        128 => return logq(x),
        else => @compileError("unreachable"),
    }
}

test "logf() special" {
    try expectEqual(logf(0.0), -math.inf(f32));
    try expectEqual(logf(-0.0), -math.inf(f32));
    try expectEqual(logf(1.0), 0.0);
    try expectEqual(logf(math.e), 1.0);
    try expectEqual(logf(math.inf(f32)), math.inf(f32));
    try expect(math.isNan(logf(-1.0)));
    try expect(math.isNan(logf(-math.inf(f32))));
    try expect(math.isNan(logf(math.nan(f32))));
    try expect(math.isNan(logf(math.snan(f32))));
}

test "logf() sanity" {
    try expect(math.isNan(logf(-0x1.0223a0p+3)));
    try expectEqual(logf(0x1.161868p+2), 0x1.7815b0p+0);
    try expect(math.isNan(logf(-0x1.0c34b4p+3)));
    try expect(math.isNan(logf(-0x1.a206f0p+2)));
    try expectEqual(logf(0x1.288bbcp+3), 0x1.1cfcd6p+1);
    try expectEqual(logf(0x1.52efd0p-1), -0x1.a6694cp-2);
    try expect(math.isNan(logf(-0x1.a05cc8p-2)));
    try expectEqual(logf(0x1.1f9efap-1), -0x1.2742bap-1);
    try expectEqual(logf(0x1.8c5db0p-1), -0x1.062160p-2);
    try expect(math.isNan(logf(-0x1.5b86eap-1)));
}

test "logf() boundary" {
    try expectEqual(logf(0x1.fffffep+127), 0x1.62e430p+6); // Max input value
    try expectEqual(logf(0x1p-149), -0x1.9d1da0p+6); // Min positive input value
    try expect(math.isNan(logf(-0x1p-149))); // Min negative input value
    try expectEqual(logf(0x1.000002p+0), 0x1.fffffep-24); // Last value before result reaches +0
    try expectEqual(logf(0x1.fffffep-1), -0x1p-24); // Last value before result reaches -0
    try expectEqual(logf(0x1p-126), -0x1.5d58a0p+6); // First subnormal
    try expect(math.isNan(logf(-0x1p-126))); // First negative subnormal
}

test "log() special" {
    try expectEqual(log(0.0), -math.inf(f64));
    try expectEqual(log(-0.0), -math.inf(f64));
    try expectEqual(log(1.0), 0.0);
    try expectEqual(log(math.e), 1.0);
    try expectEqual(log(math.inf(f64)), math.inf(f64));
    try expect(math.isNan(log(-1.0)));
    try expect(math.isNan(log(-math.inf(f64))));
    try expect(math.isNan(log(math.nan(f64))));
    try expect(math.isNan(log(math.snan(f64))));
}

test "log() sanity" {
    try expect(math.isNan(log(-0x1.02239f3c6a8f1p+3)));
    try expectEqual(log(0x1.161868e18bc67p+2), 0x1.7815b08f99c65p+0);
    try expect(math.isNan(log(-0x1.0c34b3e01e6e7p+3)));
    try expect(math.isNan(log(-0x1.a206f0a19dcc4p+2)));
    try expectEqual(log(0x1.288bbb0d6a1e6p+3), 0x1.1cfcd53d72604p+1);
    try expectEqual(log(0x1.52efd0cd80497p-1), -0x1.a6694a4a85621p-2);
    try expect(math.isNan(log(-0x1.a05cc754481d1p-2)));
    try expectEqual(log(0x1.1f9ef934745cbp-1), -0x1.2742bc03d02ddp-1);
    try expectEqual(log(0x1.8c5db097f7442p-1), -0x1.06215de4a3f92p-2);
    try expect(math.isNan(log(-0x1.5b86ea8118a0ep-1)));
}

test "log() boundary" {
    try expectEqual(log(0x1.fffffffffffffp+1023), 0x1.62e42fefa39efp+9); // Max input value
    try expectEqual(log(0x1p-1074), -0x1.74385446d71c3p+9); // Min positive input value
    try expect(math.isNan(log(-0x1p-1074))); // Min negative input value
    try expectEqual(log(0x1.0000000000001p+0), 0x1.fffffffffffffp-53); // Last value before result reaches +0
    try expectEqual(log(0x1.fffffffffffffp-1), -0x1p-53); // Last value before result reaches -0
    try expectEqual(log(0x1p-1022), -0x1.6232bdd7abcd2p+9); // First subnormal
    try expect(math.isNan(log(-0x1p-1022))); // First negative subnormal
}
