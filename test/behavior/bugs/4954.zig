const builtin = @import("builtin");

fn f(buf: []u8) void {
    _ = &buf[@sizeOf(u32)];
}

test "crash" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var buf: [4096]u8 = undefined;
    f(&buf);
}
