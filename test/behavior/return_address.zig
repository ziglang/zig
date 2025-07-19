const testing = @import("std").testing;
const builtin = @import("builtin");

fn retAddr() usize {
    return @returnAddress();
}

test "return address" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    _ = retAddr();
    // TODO: #14938
    try testing.expect(0 == comptime retAddr());
}
