const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const common = @import("common.zig");

comptime {
    @export(&scalbln, .{ .name = "scalbln", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalblnf, .{ .name = "scalblnf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalblnl, .{ .name = "scalblnl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn scalbln(x: f64, n: c_long) callconv(.c) f64 {
    // mirror musl implementation - clamp c_long to i32
    const clamped_n: i32 = @intCast(math.clamp(n, math.minInt(i32), math.maxInt(i32)));
    return math.ldexp(x, clamped_n);
}

test "scalbln" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/scalbln.h
    try expect(scalbln(-0x1.02239f3c6a8f1p+3, -2) == -0x1.02239f3c6a8f1p+1);
    try expect(scalbln(0x1.161868e18bc67p+2, -1) == 0x1.161868e18bc67p+1);
    try expect(scalbln(0x1.288bbb0d6a1e6p+3, 2) == 0x1.288bbb0d6a1e6p+5);
    try expect(scalbln(0x1.52efd0cd80497p-1, 3) == 0x1.52efd0cd80497p+2);
    try expect(scalbln(0x1.1f9ef934745cbp-1, 5) == 0x1.1f9ef934745cbp+4);
    try expect(scalbln(0x1.8c5db097f7442p-1, 6) == 0x1.8c5db097f7442p+5);
}

test "scalbln.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/scalbln.h
    try expect(math.isNan(scalbln(math.nan(f64), 0)));
    try expect(math.isPositiveInf(scalbln(math.inf(f64), 0)));
    try expect(scalbln(0x1p+0, 0) == 0x1p+0);
    try expect(scalbln(0x1p+0, 1) == 0x1p+1);
    try expect(scalbln(0x1p+0, -1) == 0x1p-1);
}

pub fn scalblnf(x: f32, n: c_long) callconv(.c) f32 {
    const clamped_n: i32 = @intCast(math.clamp(n, math.minInt(i32), math.maxInt(i32)));
    return math.ldexp(x, clamped_n);
}

test "scalblnf" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/sanity/scalbnf.h
    try expect(scalblnf(-0x1.0223ap+3, -2) == -0x1.0223ap+1);
    try expect(scalblnf(0x1.161868p+2, -1) == 0x1.161868p+1);
    try expect(scalblnf(0x1.52efdp-1, 3) == 0x1.52efdp+2);
    try expect(scalblnf(0x1.1f9efap-1, 5) == 0x1.1f9efap+4);
    try expect(scalblnf(0x1.8c5dbp-1, 6) == 0x1.8c5dbp+5);
}

test "scalblnf.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:/src/math/special/scalbnf.h
    try expect(math.isNan(scalblnf(math.nan(f32), 0)));
    try expect(math.isPositiveInf(scalblnf(math.inf(f32), 0)));
    try expect(scalblnf(0x1p+0, 0) == 0x1p+0);
    try expect(scalblnf(0x1p+0, 1) == 0x1p+1);
    try expect(scalblnf(0x1p+0, -1) == 0x1p-1);
}

pub fn scalblnl(x: c_longdouble, n: c_long) callconv(.c) c_longdouble {
    const clamped_n: i32 = @intCast(math.clamp(n, math.minInt(i32), math.maxInt(i32)));
    return math.ldexp(x, clamped_n);
}

test "scalblnl" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:src/math/sanity/scalblnl.h
    const cases = [_]struct { x: c_longdouble, n: c_int, expected: c_longdouble }{
        .{ .x = -0x1.02239f3c6a8f13dep+3, .n = -2, .expected = -0x1.02239f3c6a8f13dep+1 },
        .{ .x = 0x1.161868e18bc67782p+2, .n = -1, .expected = 0x1.161868e18bc67782p+1 },
        .{ .x = -0x1.0c34b3e01e6e682cp+3, .n = 0, .expected = -0x1.0c34b3e01e6e682cp+3 },
        .{ .x = -0x1.a206f0a19dcc3948p+2, .n = 1, .expected = -0x1.a206f0a19dcc3948p+3 },
        .{ .x = 0x1.288bbb0d6a1e5bdap+3, .n = 2, .expected = 0x1.288bbb0d6a1e5bdap+5 },
        .{ .x = 0x1.52efd0cd80496a5ap-1, .n = 3, .expected = 0x1.52efd0cd80496a5ap+2 },
        .{ .x = -0x1.a05cc754481d0bdp-2, .n = 4, .expected = -0x1.a05cc754481d0bdp+2 },
        .{ .x = 0x1.1f9ef934745cad6p-1, .n = 5, .expected = 0x1.1f9ef934745cad6p+4 },
        .{ .x = 0x1.8c5db097f744257ep-1, .n = 6, .expected = 0x1.8c5db097f744257ep+5 },
        .{ .x = -0x1.5b86ea8118a0e2bcp-1, .n = 7, .expected = -0x1.5b86ea8118a0e2bcp+6 },
    };
    for (cases) |case| {
        try expect(scalblnl(case.x, case.n) == case.expected);
    }
}

test "scalblnl.special" {
    // Ported from libc-test
    // https://repo.or.cz/libc-test.git/blob/HEAD:src/math/special/scalblnl.h
    try expect(math.isNan(scalblnl(math.nan(c_longdouble), 0)));
    try expect(math.isPositiveInf(scalblnl(math.inf(c_longdouble), 0)));
    try expect(scalblnf(0x1p+0, 0) == 0x1p+0);
    try expect(scalblnf(0x1p+0, 1) == 0x1p+1);
    try expect(scalblnf(0x1p+0, -1) == 0x1p-1);
}
