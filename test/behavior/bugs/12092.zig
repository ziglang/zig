const std = @import("std");
const builtin = @import("builtin");

const Foo = struct {
    a: Bar,
};

const Bar = struct {
    b: u32,
};

fn takeFoo(foo: *const Foo) !void {
    try std.testing.expectEqual(@as(u32, 24), foo.a.b);
}

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var baz: u32 = 24;
    try takeFoo(&.{
        .a = .{
            .b = baz,
        },
    });
}
