const std = @import("std");

const foo: u4 = 2;
const a: u7 = brk: switch (foo) {
        0, 1 => |n| n * 9,
        2 => continue :brk 1,
        3 => 4,
        else => 5,
};

pub fn main() !void {
    try std.testing.expect(a == 9);
}

// run
// backend=llvm
//
