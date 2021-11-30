const std = @import("std");

const A = struct {
    pub const B = bool;
};

const C = struct {
    usingnamespace A;
};

test "basic usingnamespace" {
    try std.testing.expect(C.B == bool);
}
