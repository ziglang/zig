const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const common = @import("common.zig");
const ldexp = @import("ldexp.zig");

comptime {
    @export(&scalbn, .{ .name = "scalbn", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalbnf, .{ .name = "scalbnf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalbnl, .{ .name = "scalbnl", .linkage = common.linkage, .visibility = common.visibility });
}

pub const scalbn = ldexp.ldexp;

test "scalbn" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexp.h
    try expect(scalbn(-0x1.02239f3c6a8f1p+3, -2) == -0x1.02239f3c6a8f1p+1);
}

test "scalbn.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexp.h
    try expect(math.isNan(scalbn(math.nan(f64), 0)));
    try expect(math.isPositiveInf(scalbn(math.inf(f64), 0)));
}

pub const scalbnf = ldexp.ldexpf;

test "scalbnf" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpf.h
    try expect(scalbnf(-0x1.0223ap+3, -2) == -0x1.0223ap+1);
}

test "scalbnf.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpf.h
    try expect(math.isNan(scalbnf(math.nan(f32), 0)));
    try expect(math.isPositiveInf(scalbnf(math.inf(f32), 0)));
}

pub const scalbnl = ldexp.ldexpl;

test "scalbnl" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/ldexpl.h
    const x: c_longdouble = -0x1.02239f3c6a8f13dep+3;
    const expected: c_longdouble = -0x1.02239f3c6a8f13dep+1;
    try expect(scalbnl(x, -2) == expected);
}

test "scalbnl.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/ldexpl.h
    try expect(math.isNan(scalbnl(math.nan(c_longdouble), 0)));
    try expect(math.isPositiveInf(scalbnl(math.inf(c_longdouble), 0)));
}
