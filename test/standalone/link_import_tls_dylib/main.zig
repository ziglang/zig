const std = @import("std");

extern threadlocal var a: i32;

test {
    try std.testing.expect(a == 0);
}
