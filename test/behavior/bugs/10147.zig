const std = @import("std");

test "uses correct LLVM builtin" {
    var x: u32 = 0x1;
    var y: @Vector(4, u32) = [_]u32{ 0x1, 0x1, 0x1, 0x1 };
    // The stage1 compiler used to call the same builtin function for both
    // scalar and vector inputs, causing the LLVM module verification to fail.
    var a = @clz(u32, x);
    var b = @clz(u32, y);
    try std.testing.expectEqual(@as(u6, 31), a);
    try std.testing.expectEqual([_]u6{ 31, 31, 31, 31 }, b);
}
