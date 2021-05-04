const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const Keys = struct {
    up: bool,
    down: bool,
    left: bool,
    right: bool,
};
var keys: Keys = undefined;
test "zero keys with @memset" {
    @memset(@ptrCast([*]u8, &keys), 0, @sizeOf(@TypeOf(keys)));
    try expect(!keys.up);
    try expect(!keys.down);
    try expect(!keys.left);
    try expect(!keys.right);
}
