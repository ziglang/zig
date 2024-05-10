const std = @import("std");

const Foo = enum {
    a,
    b,
    c,
};

pub fn main() void {
    var a: u2 = 3;
    _ = &a;
    const b: Foo = @enumFromInt(a);
    std.debug.print("value: {s}\n", .{@tagName(b)});
}

// exe=fail
