const std = @import("std");

pub fn main() !void {
    var val: u7 = 8;
    _ = &val;
    const a: u7 = brk: switch (val) {
        0, 1 => |n| n * 2,
        8 => continue :brk 1,
        3 => 4,
        else => |m| m * 3,
    };
    std.debug.print("{}", .{a});
    try std.testing.expect(a == 2);
}

// run
// backend=llvm
//
