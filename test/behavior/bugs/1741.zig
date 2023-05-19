const std = @import("std");
const builtin = @import("builtin");

test "fixed" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const x: f32 align(128) = 12.34;
    try std.testing.expect(@ptrToInt(&x) % 128 == 0);
}
