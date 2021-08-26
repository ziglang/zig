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
    try std.testing.expect(@ptrCast(*const u8, &flag_b).* == 1);
}

pub fn b(x: *X) !void {
    try a(0, 1, 2, 3, 4, x.x.a, x.x.b);
}

test "bug 9584" {
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
}
