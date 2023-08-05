const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_spirv64) return error.SkipZigTest;

    try std.testing.expect(for ([1]u8{0}) |x| {
        if (x == 0) break true;
    } else false);
}
