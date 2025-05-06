const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&bzero, .{ .name = "bzero", .linkage = common.linkage, .visibility = common.visibility });
}

fn bzero(s: *anyopaque, n: usize) void {
    _ = std.zig.c_builtins.__builtin_memset(s, 0, n);
}

test "bzero" {
    var array: [10]u8 = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
    var a = std.mem.zeroes([array.len]u8);
    a[9] = '0';
    bzero(&array[0], 9);
    try std.testing.expect(std.mem.eql(u8, &array, &a));
}
