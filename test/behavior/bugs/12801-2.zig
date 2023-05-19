const std = @import("std");
const builtin = @import("builtin");

const Auto = struct {
    auto: [max_len]u8 = undefined,
    offset: u64 = 0,

    comptime capacity: *const fn () u64 = capacity,

    const max_len: u64 = 32;

    fn capacity() u64 {
        return max_len;
    }
};
test {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const a: Auto = .{ .offset = 16, .capacity = Auto.capacity };
    try std.testing.expect(a.capacity() == 32);
    try std.testing.expect((a.capacity)() == 32);
}
