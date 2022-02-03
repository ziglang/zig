const builtin = @import("builtin");

const A = struct {
    B: type,
};

fn getA() A {
    return A{ .B = u8 };
}

test "bug 1025" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    const a = getA();
    try @import("std").testing.expect(a.B == u8);
}
