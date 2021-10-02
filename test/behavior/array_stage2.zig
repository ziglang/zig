const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const expect = testing.expect;

test "array mult at runtime" {
    var a: u8 = 'a';
    const z: [6]u8 = [2]u8{ a, 'b' } ** 3;
    try expect(std.mem.eql(u8, &z, "ababab"));
}

test "array cat at runtime" {
    var a: u8 = 'a';
    var c: u8 = 'c';
    const z: [3]u8 = [2]u8{ a, 'b' } ++ [1]u8{c};
    try expect(std.mem.eql(u8, &z, "abc"));
}
