const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

test "@intCast i32 to u7" {
    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    try expect(z == 0xff);
}
