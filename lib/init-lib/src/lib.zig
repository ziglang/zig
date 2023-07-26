const std = @import("std");
const testing = std.testing;

// The pub keyword signals that this function is exported for use in zig files.
// The export keyword signals that this function can be used by C. (Here, as a
// static library)
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
