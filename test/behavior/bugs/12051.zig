const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    const x = X{};
    try std.testing.expectEqual(@as(u16, 0), x.y.a);
    try std.testing.expectEqual(false, x.y.b);
    try std.testing.expectEqual(Z{ .a = 0 }, x.y.c);
    try std.testing.expectEqual(Z{ .a = 0 }, x.y.d);
}

const X = struct {
    y: Y = Y.init(),
};

const Y = struct {
    a: u16,
    b: bool,
    c: Z,
    d: Z,

    fn init() Y {
        return .{
            .a = 0,
            .b = false,
            .c = @bitCast(Z, @as(u32, 0)),
            .d = @bitCast(Z, @as(u32, 0)),
        };
    }
};

const Z = packed struct {
    a: u32,
};
