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
    expect(!keys.up);
    expect(!keys.down);
    expect(!keys.left);
    expect(!keys.right);
}
