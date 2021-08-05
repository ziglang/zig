const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "one param, explicit comptime" {
    var x: usize = 0;
    x += checkSize(i32);
    x += checkSize(bool);
    x += checkSize(bool);
    try expect(x == 6);
}

fn checkSize(comptime T: type) usize {
    return @sizeOf(T);
}
