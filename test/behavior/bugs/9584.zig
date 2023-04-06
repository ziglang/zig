const builtin = @import("builtin");
const std = @import("std");

const A = packed struct {
    a: bool,
    b: bool,
    c: bool,
    d: bool,

    e: bool,
    f: bool,
    g: bool,
    h: bool,
};

const X = union {
    x: A,
    y: u64,
};

pub fn a(
    x0: i32,
    x1: i32,
    x2: i32,
    x3: i32,
    x4: i32,
    flag_a: bool,
    flag_b: bool,
) !void {
    _ = x0;
    _ = x1;
    _ = x2;
    _ = x3;
    _ = x4;
    _ = flag_a;
    // With this bug present, `flag_b` would actually contain the value 17.
    // Note: this bug only presents itself on debug mode.
    const flag_b_byte: u8 = @boolToInt(flag_b);
    try std.testing.expect(flag_b_byte == 1);
}

pub fn b(x: *X) !void {
    try a(0, 1, 2, 3, 4, x.x.a, x.x.b);
}

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var flags = A{
        .a = false,
        .b = true,
        .c = false,
        .d = false,

        .e = false,
        .f = true,
        .g = false,
        .h = false,
    };
    var x = X{
        .x = flags,
    };
    try b(&x);
    comptime if (@sizeOf(A) != 1) unreachable;
}
