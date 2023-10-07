const std = @import("std");
const builtin = @import("builtin");

const T = struct {
    next: @TypeOf(null, @as(*const T, undefined)),
};

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var t: T = .{ .next = null };
    try std.testing.expect(t.next == null);
}
