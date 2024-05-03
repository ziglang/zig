const std = @import("std");
const expect = std.testing.expect;

const Point = struct {x: i32, y: i32};

test "anonymous struct literal" {
    const pt: Point = .{
        .x = 13,
        .y = 67,
    };
    try expect(pt.x == 13);
    try expect(pt.y == 67);
}

// test
