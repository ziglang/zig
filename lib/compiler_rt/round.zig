//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/roundf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/round.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__roundh, .{ .name = "__roundh", .linkage = common.linkage, .visibility = common.visibility });
    @export(&roundf, .{ .name = "roundf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&round, .{ .name = "round", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__roundx, .{ .name = "__roundx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&roundq, .{ .name = "roundf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&roundq, .{ .name = "roundq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&roundl, .{ .name = "roundl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __roundh(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(roundf(x));
}

pub fn roundf(x_: f32) callconv(.C) f32 {
    const f32_toint = 1.0 / math.floatEps(f32);

    var x = x_;
    const u: u32 = @bitCast(x);
    const e = (u >> 23) & 0xFF;
    var y: f32 = undefined;

    if (e >= 0x7F + 23) {
        return x;
    }
    if (u >> 31 != 0) {
        x = -x;
    }
    if (e < 0x7F - 1) {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + f32_toint);
        return 0 * @as(f32, @bitCast(u));
    }

    y = x + f32_toint - f32_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 31 != 0) {
        return -y;
    } else {
        return y;
    }
}

pub fn round(x_: f64) callconv(.C) f64 {
    const f64_toint = 1.0 / math.floatEps(f64);

    var x = x_;
    const u: u64 = @bitCast(x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52) {
        return x;
    }
    if (u >> 63 != 0) {
        x = -x;
    }
    if (e < 0x3ff - 1) {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + f64_toint);
        return 0 * @as(f64, @bitCast(u));
    }

    y = x + f64_toint - f64_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 63 != 0) {
        return -y;
    } else {
        return y;
    }
}

pub fn __roundx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(roundq(x));
}

pub fn roundq(x_: f128) callconv(.C) f128 {
    const f128_toint = 1.0 / math.floatEps(f128);

    var x = x_;
    const u: u128 = @bitCast(x);
    const e = (u >> 112) & 0x7FFF;
    var y: f128 = undefined;

    if (e >= 0x3FFF + 112) {
        return x;
    }
    if (u >> 127 != 0) {
        x = -x;
    }
    if (e < 0x3FFF - 1) {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + f128_toint);
        return 0 * @as(f128, @bitCast(u));
    }

    y = x + f128_toint - f128_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 127 != 0) {
        return -y;
    } else {
        return y;
    }
}

pub fn roundl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __roundh(x),
        32 => return roundf(x),
        64 => return round(x),
        80 => return __roundx(x),
        128 => return roundq(x),
        else => @compileError("unreachable"),
    }
}

test "round32" {
    try expect(roundf(1.3) == 1.0);
    try expect(roundf(-1.3) == -1.0);
    try expect(roundf(0.2) == 0.0);
    try expect(roundf(1.8) == 2.0);
}

test "round64" {
    try expect(round(1.3) == 1.0);
    try expect(round(-1.3) == -1.0);
    try expect(round(0.2) == 0.0);
    try expect(round(1.8) == 2.0);
}

test "round128" {
    try expect(roundq(1.3) == 1.0);
    try expect(roundq(-1.3) == -1.0);
    try expect(roundq(0.2) == 0.0);
    try expect(roundq(1.8) == 2.0);
}

test "round32.special" {
    try expect(roundf(0.0) == 0.0);
    try expect(roundf(-0.0) == -0.0);
    try expect(math.isPositiveInf(roundf(math.inf(f32))));
    try expect(math.isNegativeInf(roundf(-math.inf(f32))));
    try expect(math.isNan(roundf(math.nan(f32))));
}

test "round64.special" {
    try expect(round(0.0) == 0.0);
    try expect(round(-0.0) == -0.0);
    try expect(math.isPositiveInf(round(math.inf(f64))));
    try expect(math.isNegativeInf(round(-math.inf(f64))));
    try expect(math.isNan(round(math.nan(f64))));
}

test "round128.special" {
    try expect(roundq(0.0) == 0.0);
    try expect(roundq(-0.0) == -0.0);
    try expect(math.isPositiveInf(roundq(math.inf(f128))));
    try expect(math.isNegativeInf(roundq(-math.inf(f128))));
    try expect(math.isNan(roundq(math.nan(f128))));
}
