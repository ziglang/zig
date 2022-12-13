const std = @import("std");
test {
    try std.testing.expect(-1 == @as(i8, -3) >> 2);
    try std.testing.expect(-1 == -3 >> 2000);
}
