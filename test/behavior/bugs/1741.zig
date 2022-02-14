const std = @import("std");
const builtin = @import("builtin");

test "fixed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    const x: f32 align(128) = 12.34;
    try std.testing.expect(@ptrToInt(&x) % 128 == 0);
}
