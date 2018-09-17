const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    assertOrPanic(add(3, 7) == 10);
}
