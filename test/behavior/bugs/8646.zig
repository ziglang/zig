const std = @import("std");
const builtin = @import("builtin");

const array = [_][]const []const u8{
    &.{"hello"},
    &.{ "world", "hello" },
};

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try std.testing.expect(array[0].len == 1);
    try std.testing.expectEqualStrings("hello", array[0][0]);
}
