const std = @import("std");

const Bar = packed struct {
    const Baz = enum {
        fizz,
        buzz,
    };
};

test "issue13159" {
    const a = Bar.Baz.fizz;
    try std.testing.expect(a == .fizz);
}
