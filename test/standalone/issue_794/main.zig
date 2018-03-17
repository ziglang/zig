const c = @cImport(@cInclude("foo.h"));
const std = @import("std");
const assert = std.debug.assert;

test "c import" {
    comptime assert(c.NUMBER == 1234);
}
