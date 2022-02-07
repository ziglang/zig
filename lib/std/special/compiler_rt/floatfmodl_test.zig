const std = @import("std");
const fmodl = @import("floatfmodl.zig");
const testing = std.testing;

fn test_fmodl(a: f128, b: f128, exp: f128) !void {
    const res = fmodl.fmodl(a, b);
    try testing.expect(exp == res);
}

test "fmodl" {
    try test_fmodl(6.8, 4.0, 2.8);
    try test_fmodl(-5.0, 3.0, -2.0);
    try test_fmodl(1.0, 2.0, 1.0);
    try test_fmodl(3.0, 2.0, 1.0);
}
