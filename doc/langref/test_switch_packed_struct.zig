const std = @import("std");
const expect = std.testing.expect;

test "switch on packed struct" {
    const S = packed struct {
        a: u5,
        b: u7,
    };
    const x: S = .{ .a = 1, .b = 2 };
    const result = switch (x) {
        .{ .b = 1, .a = 2 }, .{ .a = 0, .b = 0 } => false,
        .{ .a = 1, .b = 2 } => true,
        else => false,
    };
    try expect(result);
}

// test
