const std = @import("std");

pub fn main() !void {
    const val: u7 = 2;
    const a: u7 = brk: switch (val) {
        0, 1 => 9,
        2 => continue :brk 3,
        3 => 4,
        else => 5,
    };
    try std.testing.expect(a == 4);
}

// run
// backend=llvm
//
