const std = @import("std");
const common = @import("common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.target.isMinGW()) {
        @export(&isnan, .{ .name = "isnan", .linkage = common.linkage, .visibility = common.visibility });
        @export(&isnan, .{ .name = "__isnan", .linkage = common.linkage, .visibility = common.visibility });
        @export(&isnanf, .{ .name = "isnanf", .linkage = common.linkage, .visibility = common.visibility });
        @export(&isnanf, .{ .name = "__isnanf", .linkage = common.linkage, .visibility = common.visibility });
        @export(&isnanl, .{ .name = "isnanl", .linkage = common.linkage, .visibility = common.visibility });
        @export(&isnanl, .{ .name = "__isnanl", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn isnan(x: f64) callconv(.c) c_int {
    return if (std.math.isNan(x)) 1 else 0;
}

fn isnanf(x: f32) callconv(.c) c_int {
    return if (std.math.isNan(x)) 1 else 0;
}

fn isnanl(x: c_longdouble) callconv(.c) c_int {
    return if (std.math.isNan(x)) 1 else 0;
}
