const std = @import("std");

pub fn main() void {
    var x: u8 = 0b01010101; // runtime-known
    _ = &x;
    const y = @shlExact(x, 2);
    std.debug.print("value: {}\n", .{y});
}

// exe=fail
