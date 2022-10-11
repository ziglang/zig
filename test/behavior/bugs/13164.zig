const std = @import("std");
const builtin = @import("builtin");

inline fn setLimits(min: ?u32, max: ?u32) !void {
    if (min != null and max != null) {
        try std.testing.expect(min.? <= max.?);
    }
}

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u32 = 42;
    try setLimits(x, null);
}
