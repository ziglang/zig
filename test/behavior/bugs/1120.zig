const std = @import("std");
const expect = std.testing.expect;

const A = packed struct {
    a: u2,
    b: u6,
};
const B = packed struct {
    q: u8,
    a: u2,
    b: u6,
};
test "bug 1120" {
    if (@import("builtin").zig_backend != .stage1) return error.SkipZigTest; // TODO

    var a = A{ .a = 2, .b = 2 };
    var b = B{ .q = 22, .a = 3, .b = 2 };
    var t: usize = 0;
    const ptr = switch (t) {
        0 => &a.a,
        1 => &b.a,
        else => unreachable,
    };
    try expect(ptr.* == 2);
}
