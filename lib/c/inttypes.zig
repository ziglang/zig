const std = @import("std");
const common = @import("common.zig");
const builtin = @import("builtin");
const intmax_t = std.c.intmax_t;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Functions specific to musl and wasi-libc.
        @export(&imaxabs, .{ .name = "imaxabs", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn imaxabs(a: intmax_t) callconv(.c) intmax_t {
    return @intCast(@abs(a));
}

test imaxabs {
    const val: intmax_t = -10;
    try std.testing.expectEqual(10, imaxabs(val));
}
