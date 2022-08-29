const builtin = @import("builtin");
const std = @import("std");

test "uses correct LLVM builtin" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    var x: u32 = 0x1;
    var y: @Vector(4, u32) = [_]u32{ 0x1, 0x1, 0x1, 0x1 };
    // The stage1 compiler used to call the same builtin function for both
    // scalar and vector inputs, causing the LLVM module verification to fail.
    var a = @clz(x);
    var b = @clz(y);
    try std.testing.expectEqual(@as(u6, 31), a);
    try std.testing.expectEqual([_]u6{ 31, 31, 31, 31 }, b);
}
