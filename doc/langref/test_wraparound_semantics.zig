const std = @import("std");
const expect = std.testing.expect;
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;

test "wraparound addition and subtraction" {
    const x: i32 = maxInt(i32);
    const min_val = x +% 1;
    try expect(min_val == minInt(i32));
    const max_val = min_val -% 1;
    try expect(max_val == maxInt(i32));
}

// test
