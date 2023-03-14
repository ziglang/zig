const std = @import("std");
const builtin = @import("builtin");

const Foo = extern struct {
    a: u8 align(1),
    b: u16 align(1),
};

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    const foo = Foo{
        .a = 1,
        .b = 2,
    };
    try std.testing.expectEqual(1, foo.a);
    try std.testing.expectEqual(2, foo.b);
}
