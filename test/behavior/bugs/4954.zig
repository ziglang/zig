const builtin = @import("builtin");

fn f(buf: []u8) void {
    _ = &buf[@sizeOf(u32)];
}

test "crash" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var buf: [4096]u8 = undefined;
    f(&buf);
}
