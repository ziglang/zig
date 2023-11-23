//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/floorf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/floor.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__floorh, .{ .name = "__floorh", .linkage = common.linkage, .visibility = common.visibility });
    @export(floorf, .{ .name = "floorf", .linkage = common.linkage, .visibility = common.visibility });
    @export(floor, .{ .name = "floor", .linkage = common.linkage, .visibility = common.visibility });
    @export(__floorx, .{ .name = "__floorx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(floorq, .{ .name = "floorf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(floorq, .{ .name = "floorq", .linkage = common.linkage, .visibility = common.visibility });
    @export(floorl, .{ .name = "floorl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floorh(x: f16) callconv(.C) f16 {
    var u: u16 = @bitCast(x);
    const e = @as(i16, @intCast((u >> 10) & 31)) - 15;
    var m: u16 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 10) {
        return x;
    }

    if (e >= 0) {
        m = @as(u16, 1023) >> @intCast(e);
        if (u & m == 0) {
            return x;
        }
        mem.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 15 != 0) {
            u += m;
        }
        return @bitCast(u & ~m);
    } else {
        mem.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 15 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

pub fn floorf(x: f32) callconv(.C) f32 {
    var u: u32 = @bitCast(x);
    const e = @as(i32, @intCast((u >> 23) & 0xFF)) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    }

    if (e >= 0) {
        m = @as(u32, 0x007FFFFF) >> @intCast(e);
        if (u & m == 0) {
            return x;
        }
        mem.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 != 0) {
            u += m;
        }
        return @bitCast(u & ~m);
    } else {
        mem.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

pub fn floor(x: f64) callconv(.C) f64 {
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
        mem.doNotOptimizeAway(y);
        if (u >> 63 != 0) {
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

pub fn __floorx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(floorq(x));
}

pub fn floorq(x: f128) callconv(.C) f128 {
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
        mem.doNotOptimizeAway(y);
        if (u >> 127 != 0) {
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

pub fn floorl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __floorh(x),
        32 => return floorf(x),
        64 => return floor(x),
        80 => return __floorx(x),
        128 => return floorq(x),
        else => @compileError("unreachable"),
    }
}

test "floor16" {
    try expect(__floorh(1.3) == 1.0);
    try expect(__floorh(-1.3) == -2.0);
    try expect(__floorh(0.2) == 0.0);
}

test "floor32" {
    try expect(floorf(1.3) == 1.0);
    try expect(floorf(-1.3) == -2.0);
    try expect(floorf(0.2) == 0.0);
}

test "floor64" {
    try expect(floor(1.3) == 1.0);
    try expect(floor(-1.3) == -2.0);
    try expect(floor(0.2) == 0.0);
}

test "floor128" {
    try expect(floorq(1.3) == 1.0);
    try expect(floorq(-1.3) == -2.0);
    try expect(floorq(0.2) == 0.0);
}

test "floor16.special" {
    try expect(__floorh(0.0) == 0.0);
    try expect(__floorh(-0.0) == -0.0);
    try expect(math.isPositiveInf(__floorh(math.inf(f16))));
    try expect(math.isNegativeInf(__floorh(-math.inf(f16))));
    try expect(math.isNan(__floorh(math.nan(f16))));
}

test "floor32.special" {
    try expect(floorf(0.0) == 0.0);
    try expect(floorf(-0.0) == -0.0);
    try expect(math.isPositiveInf(floorf(math.inf(f32))));
    try expect(math.isNegativeInf(floorf(-math.inf(f32))));
    try expect(math.isNan(floorf(math.nan(f32))));
}

test "floor64.special" {
    try expect(floor(0.0) == 0.0);
    try expect(floor(-0.0) == -0.0);
    try expect(math.isPositiveInf(floor(math.inf(f64))));
    try expect(math.isNegativeInf(floor(-math.inf(f64))));
    try expect(math.isNan(floor(math.nan(f64))));
}

test "floor128.special" {
    try expect(floorq(0.0) == 0.0);
    try expect(floorq(-0.0) == -0.0);
    try expect(math.isPositiveInf(floorq(math.inf(f128))));
    try expect(math.isNegativeInf(floorq(-math.inf(f128))));
    try expect(math.isNan(floorq(math.nan(f128))));
}
