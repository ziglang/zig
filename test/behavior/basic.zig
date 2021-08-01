const std = @import("std");
const expect = std.testing.expect;

// normal comment

/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() void {}

test "empty function with comments" {
    emptyFunctionWithComments();
}

test "truncate" {
    try expect(testTruncate(0x10fd) == 0xfd);
    comptime try expect(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) u8 {
    return @truncate(u8, x);
}
