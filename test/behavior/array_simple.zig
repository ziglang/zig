const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

test "array to slice" {
    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    const a_slice: []align(1) const u32 = @as(*const [1]u32, &a)[0..];
    const b_slice: []align(1) const u32 = @as(*const [1]u32, &b)[0..];
    try expect(a_slice[0] + b_slice[0] == 7);

    const d: []const u32 = &[2]u32{ 1, 2 };
    const e: []const u32 = &[3]u32{ 3, 4, 5 };
    try expect(d[0] + e[0] + d[1] + e[1] == 10);
}
