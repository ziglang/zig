const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const common = @import("common.zig");
const scalbn = @import("scalbn.zig");

comptime {
    @export(&scalbln, .{ .name = "scalbln", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalblnf, .{ .name = "scalblnf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalblnl, .{ .name = "scalblnl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn scalbln(x: f64, n: c_long) callconv(.c) f64 {
    // mirror musl implementation - clamp c_long to i32
    const clamped_n: i32 = math.clamp(n, math.minInt(i32), math.maxInt(i32));
    return scalbn.scalbn(x, clamped_n);
}

test "scalbln" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexp.h
    try expect(scalbln(-0x1.02239f3c6a8f1p+3, -2) == -0x1.02239f3c6a8f1p+1);
}

test "scalbln.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexp.h
    try expect(math.isNan(scalbln(math.nan(f64), 0)));
    try expect(math.isPositiveInf(scalbln(math.inf(f64), 0)));
}

pub fn scalblnf(x: f32, n: c_long) callconv(.c) f32 {
    const clamped_n: i32 = math.clamp(n, math.minInt(i32), math.maxInt(i32));
    return scalbn.scalbnf(x, clamped_n);
}

test "scalblnf" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpf.h
    try expect(scalblnf(-0x1.0223ap+3, -2) == -0x1.0223ap+1);
}

test "scalblnf.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpf.h
    try expect(math.isNan(scalblnf(math.nan(f32), 0)));
    try expect(math.isPositiveInf(scalblnf(math.inf(f32), 0)));
}

pub fn scalblnl(x: c_longdouble, n: c_long) callconv(.c) c_longdouble {
    const clamped_n: i32 = math.clamp(n, math.minInt(i32), math.maxInt(i32));
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return scalbn.scalbnl(@as(f16, x), clamped_n),
        32 => return scalbn.scalbnl(@as(f32, x), clamped_n),
        64 => return scalbn.scalbnl(@as(f64, x), clamped_n),
        80 => return scalbn.scalbnl(@as(f80, x), clamped_n),
        128 => return scalbn.scalbnl(@as(f128, x), clamped_n),
        else => @compileError("unreachable"),
    }
}


test "scalblnl" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpl.h
    const x: c_longdouble = -0x1.02239f3c6a8f13dep+3;
    const expected: c_longdouble = -0x1.02239f3c6a8f13dep+1;
    try expect(scalblnl(x, -2) == expected);
}

test "scalblnl.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpl.h
    try expect(math.isNan(scalblnl(math.nan(c_longdouble), 0)));
    try expect(math.isPositiveInf(scalblnl(math.inf(c_longdouble), 0)));
}
