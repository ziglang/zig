const std = @import("std");

extern threadlocal var a: i32;
extern fn getA() i32;

fn getA2() i32 {
    return a;
}

test {
    a = 2;
    try std.testing.expect(getA() == 2);
    try std.testing.expect(2 == getA2());
    try std.testing.expect(getA() == getA2());
}
