const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const common = @import("common.zig");
const ldexp = @import("ldexp.zig");

comptime {
    @export(&ldexp.ldexp, .{ .name = "scalbn", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexp.ldexpf, .{ .name = "scalbnf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&ldexp.ldexpl, .{ .name = "scalbnl", .linkage = common.linkage, .visibility = common.visibility });
}
