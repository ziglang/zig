const std = @import("std");

const Tag = enum {
    a,
    b,
    c,
};

const tag = Tag.a;
const b = brk: switch (tag ) {
    .a => {
        continue :brk .c;
    },
    .b => {
        break :brk false;
    },
    .c => {
        continue :brk .b;
    },
};

pub fn main() !void {
    try std.testing.expect(b == false);
}

// run
// backend=llvm
//
