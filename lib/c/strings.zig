const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&bzero, .{ .name = "bzero", .linkage = common.linkage, .visibility = common.visibility });
}

fn bzero(s: *anyopaque, n: usize) callconv(.c) void {
    const s_cast: [*]u8 = @ptrCast(s);
    @memset(s_cast[0..n], 0);
}

test bzero {
    var array: [10]u8 = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
    var a = std.mem.zeroes([array.len]u8);
    a[9] = '0';
    bzero(&array[0], 9);
    try std.testing.expect(std.mem.eql(u8, &array, &a));
}
