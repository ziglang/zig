const std = @import("std");

const Tag = enum {
    a,
    b,
    c,
};

const Val = union(Tag) {
    a: u8,
    b: bool,
    c: i32,
};

const val = Val{ .a = 3 };
const b = brk: switch (val) {
    .a => |v| {
        const c: i32 = @intCast(v);
        continue :brk Val{ .c = c };
    },
    .b => |v| {
        break :brk !v;
    },
    .c => |v| {
        continue :brk Val{ .b = v < 4 };
    },
};

pub fn main() !void {
    try std.testing.expect(b == false);
}

// run
// backend=llvm
//
