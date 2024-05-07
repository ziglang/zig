const std = @import("std");
const expect = std.testing.expect;

test "coercing large integer type to smaller one when value is comptime-known to fit" {
    const x: u64 = 255;
    const y: u8 = x;
    try expect(y == 255);
}

// test
