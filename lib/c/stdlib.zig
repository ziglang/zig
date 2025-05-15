const std = @import("std");
const common = @import("common.zig");
const c = @cImport({
    @cInclude("stdint.h");
});
const c_intmax_t = c.intmax_t;

comptime {
    @export(&abs, .{ .name = "abs", .linkage = common.linkage, .visibility = common.visibility });
    @export(&imaxabs, .{ .name = "imaxabs", .linkage = common.linkage, .visibility = common.visibility });
    @export(&labs, .{ .name = "labs", .linkage = common.linkage, .visibility = common.visibility });
    @export(&llabs, .{ .name = "llabs", .linkage = common.linkage, .visibility = common.visibility });
}

fn abs(a: c_int) callconv(.c) c_int {
    return if (a > 0) a else -a;
}

fn imaxabs(a: c_intmax_t) callconv(.c) c_intmax_t {
    return if (a > 0) a else -a;
}

fn labs(a: c_long) callconv(.c) c_long {
    return if (a > 0) a else -a;
}

fn llabs(a: c_longlong) callconv(.c) c_longlong {
    return if (a > 0) a else -a;
}
