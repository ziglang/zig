const std = @import("std");
const expect = std.testing.expect;
const common = @import("common.zig");
const ldexp = @import("ldexp.zig");

comptime {
    @export(&scalbn, .{ .name = "scalbn", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalbnf, .{ .name = "scalbnf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&scalbnl, .{ .name = "scalbnl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn scalbn(x: f64, n: i32) callconv(.c) f64 {
    return ldexp.ldexp(x, n);
}

pub fn scalbnf(x: f32, n: i32) callconv(.c) f32 {
    return ldexp.ldexpf(x, n);
}

pub fn scalbnl(x: c_longdouble, n: i32) callconv(.c) c_longdouble {
    return ldexp.ldexpl(x, n);
}
