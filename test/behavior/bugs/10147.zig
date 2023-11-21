const builtin = @import("builtin");
const std = @import("std");

test "test calling @clz on both vector and scalar inputs" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 0x1;
    _ = &x;
    var y: @Vector(4, u32) = [_]u32{ 0x1, 0x1, 0x1, 0x1 };
    _ = &y;
    const a = @clz(x);
    const b = @clz(y);
    try std.testing.expectEqual(@as(u6, 31), a);
    try std.testing.expectEqual([_]u6{ 31, 31, 31, 31 }, b);
}
