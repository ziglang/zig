const builtin = @import("builtin");
const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "casting random address to function pointer" {
    randomAddressToFunction();
    comptime randomAddressToFunction();
}

fn randomAddressToFunction() void {
    var addr: usize = 0xdeadbeef;
    var ptr = @intToPtr(fn () void, addr);
}
