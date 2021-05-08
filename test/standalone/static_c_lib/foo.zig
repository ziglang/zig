const std = @import("std");
const expect = std.testing.expect;
const c = @cImport(@cInclude("foo.h"));

test "C add" {
    const result = c.add(1, 2);
    try expect(result == 3);
}

test "C extern variable" {
    try expect(c.foo == 12345);
}
