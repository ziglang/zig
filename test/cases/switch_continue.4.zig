const std = @import("std");

const a: u7 = brk: switch (2) {
    0, 1 => 9,
    2 => continue :brk 2,
    3 => 4,
    else => 5,
};

pub fn main() !void {
    try std.testing.expect(a == 2);
}

// run
// backend=llvm
//
