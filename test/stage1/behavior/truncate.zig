const std = @import("std");
const expect = std.testing.expect;

test "truncate u0 to larger integer allowed and has comptime known result" {
    var x: u0 = 0;
    const y = @truncate(u8, x);
    comptime expect(y == 0);
}
