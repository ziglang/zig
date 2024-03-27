const std = @import("std");

const val: u7 = 2;
const foo = brk: switch (val) {
    0, 1 => @panic("unreachable"),
    2 => continue :brk 3,
    3 => true,
    else => @panic("unreachable"),
};

pub fn main() !void {
    try std.testing.expect(foo == true);
}

// run
// backend=llvm
//
