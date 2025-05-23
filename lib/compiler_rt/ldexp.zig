const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const common = @import("common.zig");

comptime {
    @export(&ldexp, .{ .name = "ldexp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexpf, .{ .name = "ldexpf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexpl, .{ .name = "ldexpl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn ldexp(x: f64, n: i32) callconv(.c) f64 {
    return math.ldexp(x, n);
}

test "ldexp" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexp.h
    try expect(ldexp(-0x1.02239f3c6a8f1p+3, -2) == -0x1.02239f3c6a8f1p+1);
}

test "ldexp.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexp.h
    try expect(math.isNan(ldexp(math.nan(f64), 0)));
    try expect(math.isPositiveInf(ldexp(math.inf(f64), 0)));
}

pub fn ldexpf(x: f32, n: i32) callconv(.c) f32 {
    return math.ldexp(x, n);
}

test "ldexpf" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpf.h
    try expect(ldexpf(-0x1.0223ap+3, -2) == -0x1.0223ap+1);
}

test "ldexpf.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpf.h
    try expect(math.isNan(ldexpf(math.nan(f32), 0)));
    try expect(math.isPositiveInf(ldexpf(math.inf(f32), 0)));
}

pub fn ldexpl(x: c_longdouble, n: i32) callconv(.c) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return math.ldexp(@as(f16, x), n),
        32 => return math.ldexp(@as(f32, x), n),
        64 => return math.ldexp(@as(f64, x), n),
        80 => return math.ldexp(@as(f80, x), n),
        128 => return math.ldexp(@as(f128, x), n),
        else => @compileError("unreachable"),
    }
}

test "ldexpl" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpl.h
    const x: c_longdouble = -0x1.02239f3c6a8f13dep+3;
    const expected: c_longdouble = -0x1.02239f3c6a8f13dep+1;
    try expect(ldexpl(x, -2) == expected);
}

test "ldexpl.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpl.h
    try expect(math.isNan(ldexpl(math.nan(c_longdouble), 0)));
    try expect(math.isPositiveInf(ldexpl(math.inf(c_longdouble), 0)));
}
