const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "truncate u0 to larger integer allowed and has comptime known result" {
    var x: u0 = 0;
    const y = @truncate(u8, x);
    comptime assertOrPanic(y == 0);
}
