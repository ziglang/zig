const std = @import("std");

pub fn main() !void {
    var val: u7 = 2;
    _ = &val;
    brk: switch (val) {
        0, 1 => @panic("unreachable"),
        2 => continue :brk 3,
        3 => {},
        else => @panic("unreachable"),
    }
}

// run
// backend=llvm
//
