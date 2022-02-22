const builtin = @import("builtin");

fn foo(a: []u8) void {
    _ = a;
}

test "address of 0 length array" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var pt: [0]u8 = undefined;
    foo(&pt);
}
