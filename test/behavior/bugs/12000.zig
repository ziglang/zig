const std = @import("std");
const builtin = @import("builtin");

const T = struct {
    next: @TypeOf(null, @as(*const T, undefined)),
};

test {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var t: T = .{ .next = null };
    _ = &t;
    try std.testing.expect(t.next == null);
}
