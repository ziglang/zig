const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.object_format != .c) {
        @export(&memcpy, .{ .name = "memcpy", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn memcpy(opt_dest: ?[*]u8, opt_src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    return @call(.always_inline, @import("memmove.zig").memmove, .{ opt_dest, opt_src, len });
}
