//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

/// Returns the sum of `a` and `b`.
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test add {
    try testing.expect(add(3, 7) == 10);
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
