const c = @cImport(@cInclude("foo.h"));
const std = @import("std");
const testing = std.testing;

test "c import" {
    comptime try testing.expect(c.NUMBER == 1234);
}
