const std = @import("std");
const builtin = @import("builtin");
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    @memset(@ptrCast([*]u8, &keys)[0..@sizeOf(@TypeOf(keys))], 0);
    try expect(!keys.up);
    try expect(!keys.down);
    try expect(!keys.left);
    try expect(!keys.right);
}
