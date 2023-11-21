const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "aggregate initializers should allow initializing comptime fields, verifying equality" {
    if (true) return error.SkipZigTest; // TODO

    var x: u32 = 15;
    _ = &x;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    const a: T = .{ -1234, 5678, x + 1 };

    try expect(a[0] == -1234);
    try expect(a[1] == 5678);
    try expect(a[2] == 16);
}
