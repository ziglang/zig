const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "aggregate initializers should allow initializing comptime fields, verifying equality (stage2 only)" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest; // TODO
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    var x: u32 = 15;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    var a: T = .{ -1234, 5678, x + 1 };

    try expect(a[0] == -1234);
    try expect(a[1] == 5678);
    try expect(a[2] == 16);
}
