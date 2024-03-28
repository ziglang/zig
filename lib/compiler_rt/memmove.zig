const std = @import("std");
const common = @import("./common.zig");

comptime {
    @export(&memmove, .{ .name = "memmove", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (@intFromPtr(dest) < @intFromPtr(src)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest.?[index] = src.?[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest.?[index] = src.?[index];
        }
    }

    return dest;
}
