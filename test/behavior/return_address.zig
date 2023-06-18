const builtin = @import("builtin");
const testing = @import("std").testing;

fn retAddr() usize {
    return @returnAddress();
}

test "return address" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    _ = retAddr();
    // TODO: #14938
    try testing.expectEqual(0, comptime retAddr());
}
