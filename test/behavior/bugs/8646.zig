const std = @import("std");
const builtin = @import("builtin");

const array = [_][]const []const u8{
    &.{"hello"},
    &.{ "world", "hello" },
};

test {
    if (builtin.zig_backend == .zsf_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_spirv64) return error.SkipZigTest;

    try std.testing.expect(array[0].len == 1);
    try std.testing.expectEqualStrings("hello", array[0][0]);
}
