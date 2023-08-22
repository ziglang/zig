const std = @import("std");

extern fn foo_last() i32;
extern fn bar_last() i32;

export const one_0: i32 = 1;

export fn foo_0() i32 {
    return 1234;
}
export fn bar_0() i32 {
    return 5678;
}

pub fn main() anyerror!void {
    const foo_expected: i32 = 1 + 1234;
    const bar_expected: i32 = 5678;
    try std.testing.expectEqual(foo_expected, foo_last());
    try std.testing.expectEqual(bar_expected, bar_last());
}
