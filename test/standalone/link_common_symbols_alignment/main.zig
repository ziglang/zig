const std = @import("std");

extern var foo: i32;
extern var bar: i32;

test {
    try std.testing.expect(@ptrToInt(&foo) % 4 == 0);
    try std.testing.expect(@ptrToInt(&bar) % 4096 == 0);
}
