//! Ported from musl, which is MIT licensed.
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/truncf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/trunc.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__trunch, .{ .name = "__trunch", .linkage = common.linkage, .visibility = common.visibility });
    @export(&truncf, .{ .name = "truncf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&trunc, .{ .name = "trunc", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__truncx, .{ .name = "__truncx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&truncq, .{ .name = "truncf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&truncq, .{ .name = "truncq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&truncl, .{ .name = "truncl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __trunch(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(truncf(x));
}

pub fn truncf(x: f32) callconv(.C) f32 {
    const u: u32 = @bitCast(x);
    var e = @as(i32, @intCast(((u >> 23) & 0xFF))) - 0x7F + 9;
    var m: u32 = undefined;

    if (e >= 23 + 9) {
        return x;
    }
    if (e < 9) {
        e = 1;
    }

    m = @as(u32, math.maxInt(u32)) >> @intCast(e);
    if (u & m == 0) {
        return x;
    } else {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + 0x1p120);
        return @bitCast(u & ~m);
    }
}

pub fn trunc(x: f64) callconv(.C) f64 {
    const u: u64 = @bitCast(x);
    var e = @as(i32, @intCast(((u >> 52) & 0x7FF))) - 0x3FF + 12;
    var m: u64 = undefined;

    if (e >= 52 + 12) {
        return x;
    }
    if (e < 12) {
        e = 1;
    }

    m = @as(u64, math.maxInt(u64)) >> @intCast(e);
    if (u & m == 0) {
        return x;
    } else {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + 0x1p120);
        return @bitCast(u & ~m);
    }
}

pub fn __truncx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(truncq(x));
}

pub fn truncq(x: f128) callconv(.C) f128 {
    const u: u128 = @bitCast(x);
    var e = @as(i32, @intCast(((u >> 112) & 0x7FFF))) - 0x3FFF + 16;
    var m: u128 = undefined;

    if (e >= 112 + 16) {
        return x;
    }
    if (e < 16) {
        e = 1;
    }

    m = @as(u128, math.maxInt(u128)) >> @intCast(e);
    if (u & m == 0) {
        return x;
    } else {
        if (common.want_float_exceptions) mem.doNotOptimizeAway(x + 0x1p120);
        return @bitCast(u & ~m);
    }
}

pub fn truncl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __trunch(x),
        32 => return truncf(x),
        64 => return trunc(x),
        80 => return __truncx(x),
        128 => return truncq(x),
        else => @compileError("unreachable"),
    }
}

test "trunc32" {
    try expect(truncf(1.3) == 1.0);
    try expect(truncf(-1.3) == -1.0);
    try expect(truncf(0.2) == 0.0);
}

test "trunc64" {
    try expect(trunc(1.3) == 1.0);
    try expect(trunc(-1.3) == -1.0);
    try expect(trunc(0.2) == 0.0);
}

test "trunc128" {
    try expect(truncq(1.3) == 1.0);
    try expect(truncq(-1.3) == -1.0);
    try expect(truncq(0.2) == 0.0);
}

test "trunc32.special" {
    try expect(truncf(0.0) == 0.0); // 0x3F800000
    try expect(truncf(-0.0) == -0.0);
    try expect(math.isPositiveInf(truncf(math.inf(f32))));
    try expect(math.isNegativeInf(truncf(-math.inf(f32))));
    try expect(math.isNan(truncf(math.nan(f32))));
}

test "trunc64.special" {
    try expect(trunc(0.0) == 0.0);
    try expect(trunc(-0.0) == -0.0);
    try expect(math.isPositiveInf(trunc(math.inf(f64))));
    try expect(math.isNegativeInf(trunc(-math.inf(f64))));
    try expect(math.isNan(trunc(math.nan(f64))));
}

test "trunc128.special" {
    try expect(truncq(0.0) == 0.0);
    try expect(truncq(-0.0) == -0.0);
    try expect(math.isPositiveInf(truncq(math.inf(f128))));
    try expect(math.isNegativeInf(truncq(-math.inf(f128))));
    try expect(math.isNan(truncq(math.nan(f128))));
}
