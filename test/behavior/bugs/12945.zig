const std = @import("std");
const expect = std.testing.expect;

fn A(
    comptime T: type,
    comptime destroycb: ?*const fn (?*T) callconv(.C) void,
) !void {
    try expect(destroycb == null);
}

test {
    try A(u32, null);
}
