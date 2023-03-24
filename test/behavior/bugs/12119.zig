const std = @import("std");
const builtin = @import("builtin");

const u8x32 = @Vector(32, u8);
const u32x8 = @Vector(8, u32);

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    const zerox32: u8x32 = [_]u8{0} ** 32;
    const bigsum: u32x8 = @bitCast(u32x8, zerox32);
    try std.testing.expectEqual(0, @reduce(.Add, bigsum));
}
