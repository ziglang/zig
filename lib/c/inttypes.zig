const std = @import("std");
const common = @import("common.zig");
const intmax_t = std.c.intmax_t;

comptime {
    @export(&imaxabs, .{ .name = "imaxabs", .linkage = common.linkage, .visibility = common.visibility });
}

fn imaxabs(a: intmax_t) callconv(.c) intmax_t {
    return if (a > 0) a else -a;
}
