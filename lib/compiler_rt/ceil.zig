//! Ported from musl, which is MIT licensed.
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/ceilf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/ceil.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const expect = std.testing.expect;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__ceilh, .{ .name = "__ceilh", .linkage = common.linkage, .visibility = common.visibility });
    @export(ceilf, .{ .name = "ceilf", .linkage = common.linkage, .visibility = common.visibility });
    @export(ceil, .{ .name = "ceil", .linkage = common.linkage, .visibility = common.visibility });
    @export(__ceilx, .{ .name = "__ceilx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(ceilq, .{ .name = "ceilf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(ceilq, .{ .name = "ceilq", .linkage = common.linkage, .visibility = common.visibility });
    @export(ceill, .{ .name = "ceill", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __ceilh(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(ceilf(x));
}

pub fn ceilf(x: f32) callconv(.C) f32 {
    var u: u32 = @bitCast(x);
    var e = @as(i32, @intCast((u >> 23) & 0xFF)) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    } else if (e >= 0) {
        m = @as(u32, 0x007FFFFF) >> @as(u5, @intCast(e));
        if (u & m == 0) {
            return x;
        }
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 == 0) {
            u += m;
        }
        u &= ~m;
        return @bitCast(u);
    } else {
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    }
}

pub fn ceil(x: f64) callconv(.C) f64 {
    const f64_toint = 1.0 / math.floatEps(f64);

    const u: u64 = @bitCast(x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52 or x == 0) {
        return x;
    }

    if (u >> 63 != 0) {
        y = x - f64_toint + f64_toint - x;
    } else {
        y = x + f64_toint - f64_toint - x;
    }

    if (e <= 0x3FF - 1) {
        math.doNotOptimizeAway(y);
        if (u >> 63 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    } else if (y < 0) {
        return x + y + 1;
    } else {
        return x + y;
    }
}

pub fn __ceilx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(ceilq(x));
}

pub fn ceilq(x: f128) callconv(.C) f128 {
    const f128_toint = 1.0 / math.floatEps(f128);

    const u: u128 = @bitCast(x);
    const e = (u >> 112) & 0x7FFF;
    var y: f128 = undefined;

    if (e >= 0x3FFF + 112 or x == 0) return x;

    if (u >> 127 != 0) {
        y = x - f128_toint + f128_toint - x;
    } else {
        y = x + f128_toint - f128_toint - x;
    }

    if (e <= 0x3FFF - 1) {
        math.doNotOptimizeAway(y);
        if (u >> 127 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    } else if (y < 0) {
        return x + y + 1;
    } else {
        return x + y;
    }
}

pub fn ceill(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __ceilh(x),
        32 => return ceilf(x),
        64 => return ceil(x),
        80 => return __ceilx(x),
        128 => return ceilq(x),
        else => @compileError("unreachable"),
    }
}

test "ceil32" {
    try expect(ceilf(1.3) == 2.0);
    try expect(ceilf(-1.3) == -1.0);
    try expect(ceilf(0.2) == 1.0);
}

test "ceil64" {
    try expect(ceil(1.3) == 2.0);
    try expect(ceil(-1.3) == -1.0);
    try expect(ceil(0.2) == 1.0);
}

test "ceil128" {
    try expect(ceilq(1.3) == 2.0);
    try expect(ceilq(-1.3) == -1.0);
    try expect(ceilq(0.2) == 1.0);
}

test "ceil32.special" {
    try expect(ceilf(0.0) == 0.0);
    try expect(ceilf(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceilf(math.inf(f32))));
    try expect(math.isNegativeInf(ceilf(-math.inf(f32))));
    try expect(math.isNan(ceilf(math.nan(f32))));
}

test "ceil64.special" {
    try expect(ceil(0.0) == 0.0);
    try expect(ceil(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceil(math.inf(f64))));
    try expect(math.isNegativeInf(ceil(-math.inf(f64))));
    try expect(math.isNan(ceil(math.nan(f64))));
}

test "ceil128.special" {
    try expect(ceilq(0.0) == 0.0);
    try expect(ceilq(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceilq(math.inf(f128))));
    try expect(math.isNegativeInf(ceilq(-math.inf(f128))));
    try expect(math.isNan(ceilq(math.nan(f128))));
}
