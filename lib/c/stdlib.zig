const std = @import("std");
const common = @import("common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Functions specific to musl and wasi-libc.
        @export(&abs, .{ .name = "abs", .linkage = common.linkage, .visibility = common.visibility });
        @export(&labs, .{ .name = "labs", .linkage = common.linkage, .visibility = common.visibility });
        @export(&llabs, .{ .name = "llabs", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn abs(a: c_int) callconv(.c) c_int {
    return @intCast(@abs(a));
}

fn labs(a: c_long) callconv(.c) c_long {
    return @intCast(@abs(a));
}

fn llabs(a: c_longlong) callconv(.c) c_longlong {
    return @intCast(@abs(a));
}

test abs {
    const val: c_int = -10;
    try std.testing.expectEqual(10, abs(val));
}

test labs {
    const val: c_long = -10;
    try std.testing.expectEqual(10, labs(val));
}

test llabs {
    const val: c_longlong = -10;
    try std.testing.expectEqual(10, llabs(val));
}
