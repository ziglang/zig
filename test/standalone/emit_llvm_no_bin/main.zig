const std = @import("std");

export fn strFromFloatHelp(float: f64) void {
    var buf: [400]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d}", .{float}) catch unreachable;
}
