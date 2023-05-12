const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const string = "Hello!\x00World!";
    try std.testing.expect(@TypeOf(string) == *const [13:0]u8);

    const slice_without_sentinel: []const u8 = string[0..6];
    try std.testing.expect(@TypeOf(slice_without_sentinel) == []const u8);

    const slice_with_sentinel: [:0]const u8 = string[0..6 :0];
    try std.testing.expect(@TypeOf(slice_with_sentinel) == [:0]const u8);
}
