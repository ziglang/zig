const std = @import("std");
const expect = std.testing.expect;
const c = @cImport(@cInclude("foo.h"));

test "C add" {
    const result = c.add(1, 2);
    expect(result == 3);
}

test "C extern variable" {
    expect(c.foo == 12345);
}
