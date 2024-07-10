const std = @import("std");
const expect = std.testing.expect;

const Tuple = struct { u8, u8 };
test "coercion from homogeneous tuple to array" {
    const tuple: Tuple = .{ 5, 6 };
    const array: [2]u8 = tuple;
    _ = array;
}

// test
