const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;

pub fn main() !void {
    var x: u8 = 10;
    var b: i32 = -10;
    var c: i32 = b + x;
}
