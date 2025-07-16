const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&strlen, .{ .name = "strlen", .linkage = common.linkage, .visibility = common.visibility });
}

fn strlen(s: [*:0]const c_char) callconv(.c) usize {
    return std.mem.len(s);
}
