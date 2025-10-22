const std = @import("std");
const expect = std.testing.expect;

extern fn sub(a: i32, b: i32) i32;

test "import C sub" {
    const result = sub(2, 1);
    try expect(result == 1);
}
